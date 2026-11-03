import asyncio, inspect, json, time, uuid
from dataclasses import replace
from datetime import datetime, timezone, timedelta
from pathlib import Path
import httpx, jwt, pytest
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient
from fastmcp.exceptions import ToolError
from fastmcp.server.auth import OAuthProxy
from key_value.aio.wrappers.encryption import FernetEncryptionWrapper
from remote_mcp import MCPSettings, CasdoorOwnerVerifier, create_remote_mcp, validate_window, sample_result
from oauth_store import CloudBaseOAuthStore


@pytest.fixture
def anyio_backend(): return 'asyncio'

@pytest.fixture
def settings():
    return MCPSettings('https://health.example.com', 'https://auth.example.com', 'dedicated-client',
                       'SECRET-UPSTREAM-CLIENT', 'private-org', 'owner-user', 's'*43, Fernet.generate_key().decode())


class FakeGateway:
    def __init__(self): self.rows = {}; self.calls = []
    async def rpc(self, name, args):
        self.calls.append((name, args))
        if name == 'healthbridge_read':
            return {'items': [{'id':'sample','type':'oxygen_saturation','value':.975,'unit':'fraction',
                               'metadata':{},'source_name':'Synthetic Watch'}],
                    'page':{'limit':args['p_limit'],'offset':args.get('p_offset',0),'has_more':False}}
        assert name == 'healthbridge_oauth_kv'
        key = (args['p_collection'], args['p_key'])
        if args['p_action'] == 'put': self.rows[key] = args['p_entry']; return {'ok':True}
        if args['p_action'] == 'delete': return {'deleted': self.rows.pop(key,None) is not None}
        return {'entry':self.rows.get(key)}


@pytest.mark.anyio
async def test_encrypted_store_survives_adapter_restart_and_hashes_keys(settings):
    db = FakeGateway()
    wrapper = FernetEncryptionWrapper(CloudBaseOAuthStore(db), fernet=Fernet(settings.encryption_key.encode()))
    await wrapper.put(key='sensitive-key',value={'access_token':'SENSITIVE-OAUTH-TOKEN'},collection='tokens',ttl=60)
    serialized=json.dumps(list(db.rows.values()))
    assert 'SENSITIVE-OAUTH-TOKEN' not in serialized
    assert all(len(key[1])==64 and 'sensitive-key' not in key[1] for key in db.rows)
    restarted = FernetEncryptionWrapper(CloudBaseOAuthStore(db), fernet=Fernet(settings.encryption_key.encode()))
    assert await restarted.get(key='sensitive-key',collection='tokens') == {'access_token':'SENSITIVE-OAUTH-TOKEN'}
    assert await restarted.delete(key='sensitive-key',collection='tokens') is True
    assert await restarted.get(key='sensitive-key',collection='tokens') is None


@pytest.mark.anyio
async def test_verifier_accepts_only_signed_app_audience_and_allowlisted_owner(settings):
    key = rsa.generate_private_key(public_exponent=65537,key_size=2048)
    jwk=json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(key.public_key()));jwk.update(kid='test-key',alg='RS256',use='sig')
    async def keys(request):return httpx.Response(200,json={'keys':[jwk]})
    async with httpx.AsyncClient(transport=httpx.MockTransport(keys)) as client:
        verifier=CasdoorOwnerVerifier(settings,http_client=client)
        base={'sub':'subject','owner':'private-org','name':'owner-user','aud':'dedicated-client',
              'iss':settings.issuer,'exp':int(time.time())+300}
        def signed(claims):return jwt.encode(claims,key,algorithm='RS256',headers={'kid':'test-key'})
        assert (await verifier.verify_token(signed(base))).subject=='subject'
        for field,value in [('owner','other-org'),('name','other-user'),('aud','other-app'),('iss','https://evil.invalid'),('exp',1)]:
            assert await verifier.verify_token(signed({**base,field:value})) is None
        assert await verifier.verify_token(signed({k:v for k,v in base.items() if k!='exp'})) is None
        assert await verifier.verify_token(jwt.encode(base,'x'*32,algorithm='HS256')) is None
        assert await verifier.verify_token(signed(base)+'bad') is None
        assert await verifier.verify_token('not-a-jwt') is None


def test_filter_keeps_raw_separate_and_preserves_pagination_and_units():
    result={'items':[{'id':'raw','value':.975,'unit':'fraction','metadata':{}},
                     {'id':'daily','metadata':{'aggregation':'daily_average'}}],
            'page':{'offset':5,'limit':2,'has_more':True}}
    out=sample_result(result,'raw')
    assert out['items']==result['items'][:1] and out['page']['next_offset']==7 and out['page']['has_more']
    assert out['items'][0]['unit']=='fraction'
    assert sample_result(result,'daily_summary')['items']==result['items'][1:]
    assert len(sample_result(result,'all')['items'])==2


@pytest.mark.parametrize('start,end,limit,offset',[
    ('2026-01-01','2026-01-02',100,0), ('2026-01-02T00:00:00Z','2026-01-01T00:00:00Z',100,0),
    ('2026-01-01T00:00:00Z','2026-01-02T00:00:00Z',201,0),
    ('2026-01-01T00:00:00Z','2026-01-02T00:00:00Z',1,-1),
])
def test_query_boundaries(start,end,limit,offset):
    with pytest.raises(ToolError):validate_window(start,end,limit,offset)


def test_remote_metadata_and_unauthorized_requests(settings):
    db=FakeGateway();server,app,verifier=create_remote_mcp(db,settings)
    with TestClient(app) as client:
        r=client.post('/mcp',json={'jsonrpc':'2.0','id':1,'method':'initialize','params':{}})
        assert r.status_code==401 and 'resource_metadata' in r.headers['www-authenticate']
        assert client.post('/mcp',json={},headers={'Authorization':'Bearer forged'}).status_code==401
        metadata=client.get('/.well-known/oauth-authorization-server').json()
        assert 'S256' in metadata['code_challenge_methods_supported']
        assert metadata['issuer'].rstrip('/')==settings.public_url
        assert metadata['authorization_endpoint'].startswith(settings.public_url)
        assert client.get('/.well-known/oauth-protected-resource/mcp').json()['resource']==settings.public_url+'/mcp'
        r=client.post('/register',json={'client_name':'Attacker','redirect_uris':['https://evil.invalid/callback'],
                                      'grant_types':['authorization_code','refresh_token'],'response_types':['code'],
                                      'token_endpoint_auth_method':'none'})
        assert r.status_code>=400
    assert not any(name=='healthbridge_read' for name,_ in db.calls)
    asyncio.run(verifier.client.aclose())


@pytest.mark.anyio
async def test_authenticated_remote_mcp_protocol_and_restart(settings):
    # Seed a proxy reference grant, then exercise the actual authenticated HTTP transport.
    db=FakeGateway();server,app,verifier=create_remote_mcp(db,settings)
    module=inspect.getmodule(OAuthProxy)
    from fastmcp.server.auth import AccessToken
    async def valid_upstream(token):
        return AccessToken(token=token,client_id=settings.client_id,scopes=['openid','profile','offline_access'],
                           subject='owner',expires_at=int(time.time())+3600)
    verifier.verify_token=valid_upstream
    auth=server.auth
    await auth._upstream_token_store.put(key='grant',value=module.UpstreamTokenSet(
        upstream_token_id='grant',access_token='UPSTREAM-SECRET',refresh_token=None,refresh_token_expires_at=None,
        expires_at=time.time()+3600,token_type='Bearer',scope='openid profile offline_access',client_id='registered-client',created_at=time.time()),ttl=3600)
    await auth._jti_mapping_store.put(key='jti',value=module.JTIMapping(jti='jti',upstream_token_id='grant',created_at=time.time()),ttl=3600)
    token=auth.jwt_issuer.issue_access_token(client_id='registered-client',scopes=['openid','profile','offline_access'],jti='jti',expires_in=3600)
    # New server instance must accept the same proxy token, using the persistent encrypted state.
    server2,app2,verifier2=create_remote_mcp(db,settings);verifier2.verify_token=valid_upstream
    with TestClient(app2) as client:
        headers={'Authorization':'Bearer '+token,'Accept':'application/json, text/event-stream'}
        r=client.post('/mcp',headers=headers,json={'jsonrpc':'2.0','id':1,'method':'initialize',
            'params':{'protocolVersion':'2025-11-25','capabilities':{},'clientInfo':{'name':'test','version':'1'}}})
        assert r.status_code==200,r.text
        r=client.post('/mcp',headers=headers,json={'jsonrpc':'2.0','id':2,'method':'tools/list','params':{}})
        assert r.status_code==200,r.text
        tools=r.json()['result']['tools'];assert {t['name'] for t in tools}=={'health_samples','health_workouts','health_sync_status'}
        assert all(t['annotations']['readOnlyHint'] and not t['annotations']['destructiveHint'] for t in tools)
        r=client.post('/mcp',headers=headers,json={'jsonrpc':'2.0','id':3,'method':'tools/call',
            'params':{'name':'health_samples','arguments':{'metric_type':'oxygen_saturation',
                      'start':'2026-10-18T00:00:00+08:00','end':'2026-10-19T00:00:00+08:00'}}})
        assert r.status_code==200,r.text
        assert not r.json()['result'].get('isError')
        assert '0.975' in r.text and 'fraction' in r.text and 'UPSTREAM-SECRET' not in r.text
    await verifier.client.aclose();await verifier2.client.aclose()


def test_remote_mcp_mount_does_not_break_existing_ingestion(monkeypatch, settings):
    from app import create_app, Settings
    env={'HEALTH_MCP_ENABLED':'1','HEALTH_PUBLIC_URL':settings.public_url,
         'CASDOOR_ISSUER':settings.issuer,'CASDOOR_CLIENT_ID':settings.client_id,
         'CASDOOR_CLIENT_SECRET':settings.client_secret,'CASDOOR_ALLOWED_ORG':settings.allowed_org,
         'CASDOOR_ALLOWED_USER':settings.allowed_user,'MCP_SIGNING_KEY':settings.signing_key,
         'MCP_STORAGE_KEY':settings.encryption_key}
    for k,v in env.items():monkeypatch.setenv(k,v)
    db=FakeGateway()
    with TestClient(create_app(Settings('https://example.invalid','db','u'*43,'r'*43),db)) as client:
        assert client.get('/health').json()=={'ok':True}
        assert client.get('/ready').status_code==200
        assert client.post('/api/apple-health/sync',json={}).status_code==401
        assert client.post('/api/apple-health/sync',json={},headers={'Authorization':'Bearer '+'u'*43}).status_code==422
        assert client.post('/mcp',json={}).status_code==401
        assert client.get('/.well-known/oauth-authorization-server').status_code==200



def test_reverse_proxy_prefix_discovery_and_callbacks(settings):
    settings=replace(settings,public_url='https://healthsync.example.com/health')
    server,app,verifier=create_remote_mcp(FakeGateway(),settings)
    with TestClient(app) as client:
        # The reverse proxy strips /health on app routes, but forwards /.well-known unchanged.
        r=client.get('/.well-known/oauth-authorization-server/health')
        assert r.status_code==200,r.text
        metadata=r.json()
        assert metadata['issuer']==settings.public_url
        assert metadata['authorization_endpoint']==settings.public_url+'/authorize'
        assert metadata['token_endpoint']==settings.public_url+'/token'
        assert metadata['registration_endpoint']==settings.public_url+'/register'
        resource=client.get('/.well-known/oauth-protected-resource/health/mcp')
        assert resource.status_code==200,resource.text
        assert resource.json()['resource']==settings.public_url+'/mcp'
        r=client.post('/mcp',json={})
        assert r.status_code==401
        assert 'https://healthsync.example.com/health/.well-known/oauth-protected-resource/health/mcp' in r.headers['www-authenticate']
    asyncio.run(verifier.client.aclose())
