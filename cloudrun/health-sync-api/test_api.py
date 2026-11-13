import copy,hashlib,json
import httpx,pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from app import create_app,Settings,Gateway

class Storage:
    def __init__(self):self.calls=[]
    async def rpc(self,name,args):
        self.calls.append((name,args))
        if name=='healthbridge_ingest':return {'ok':True,'received':len(args['p_batch']['metrics']),'duplicates':0,'deleted':0,'untrusted':'not returned'}
        return {'items':[],'page':{'has_more':False,'offset':0,'limit':100}}

def sample():
    at='2026-10-18T01:00:00.123456Z'
    return {'device_id':'test-phone','export_id':'11111111-1111-4111-8111-111111111111','generated_at':at,'timezone':'Asia/Shanghai','source':'SYNTHETIC','schema_version':1,'date_range':{'start':at,'end':at},'metrics':[{'id':'healthkit:test-uuid','type':'oxygen_saturation','value':.975,'unit':'fraction','start_at':at,'end_at':at,'source_name':'Synthetic Watch','source_bundle_id':'test.watch','metadata':{'healthbridge.start_epoch_seconds':'1792285200.123456'}}],'workouts':[],'deletions':[]}

@pytest.fixture
def setup():
    storage=Storage();settings=Settings('https://example.invalid','db-secret','u'*43,'r'*43)
    with TestClient(create_app(settings,storage)) as client:yield client,storage

U={'Authorization':'Bearer '+'u'*43};R={'Authorization':'Bearer '+'r'*43}

def test_upload_contract_preserves_data_and_ack_allowlist(setup):
    c,s=setup;p=sample();r=c.post('/api/apple-health/sync',headers=U,json=p)
    assert r.status_code==200 and r.json()=={'ok':True,'received':1,'duplicates':0,'deleted':0}
    sent=s.calls[0][1]['p_batch'];m=sent['metrics'][0]
    assert m['value']==.975 and m['unit']=='fraction' and m['metadata']==p['metrics'][0]['metadata']
    assert '.123456' in m['start_at']
    expected=hashlib.sha256(json.dumps(sent,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()
    assert s.calls[0][1]['p_hash']==expected

def test_scopes_and_no_auth_do_not_reach_storage(setup):
    c,s=setup
    assert c.post('/api/apple-health/sync',json=sample()).status_code==401
    assert c.post('/api/apple-health/sync',json=sample(),headers=R).status_code==403
    assert c.get('/api/agent/metrics',headers=U).status_code==403
    assert c.get('/api/agent/metrics').status_code==401
    assert s.calls==[]

def test_read_pagination_time_and_type_forwarding(setup):
    c,s=setup
    q={'type':'oxygen_saturation','from':'2026-10-17T00:00:00Z','to':'2026-10-19T00:00:00Z','limit':12,'offset':24}
    assert c.get('/api/agent/metrics',params=q,headers=R).status_code==200
    args=s.calls[-1][1];assert args['p_type']=='oxygen_saturation' and args['p_limit']==12 and args['p_offset']==24
    assert c.get('/api/agent/metrics?limit=501',headers=R).status_code==422
    assert c.get('/api/agent/metrics?from=2026-10-18T00:00:00',headers=R).status_code==422

@pytest.mark.parametrize('change',['naive','reversed','bad_zone','nan','oversize'])
def test_invalid_payload_is_rejected_without_echoing_sample(setup,change):
    c,s=setup;p=sample()
    if change=='naive':p['metrics'][0]['start_at']='2026-10-18T01:00:00'
    elif change=='reversed':p['metrics'][0]['end_at']='2025-01-01T00:00:00Z'
    elif change=='bad_zone':p['timezone']='invalid/not-a-zone'
    elif change=='nan':p['metrics'][0]['value']='NaN'
    else:p['metrics']=p['metrics']*1001
    r=c.post('/api/apple-health/sync',json=p,headers=U)
    assert r.status_code==422 and r.json()['detail']=='Invalid request payload' and r.json()['errors'] and s.calls==[]

def test_no_context_or_env_echo(setup):
    c,s=setup
    assert c.get('/health',headers={'X-CloudBase-Context':'SENSITIVE'}).json()=={'ok':True}
    for path in ['/docs','/openapi.json','/debug','/api/hosted/workspaces']:
        assert c.get(path).status_code==404
    assert 'SENSITIVE' not in c.get('/ready').text

def test_body_size_enforced_for_chunked_request(setup):
    c,s=setup
    r=c.post('/api/apple-health/sync',content=iter([b'x'*(2*1024*1024),b'x'*(2*1024*1024+1)]),headers=U)
    assert r.status_code==413 and not s.calls

@pytest.mark.anyio
async def test_gateway_errors_do_not_leak_key_or_payload():
    g=Gateway(Settings('https://example.invalid','DB-SECRET','u'*43,'r'*43))
    await g.client.aclose()
    async def failure(request):return httpx.Response(403,json={'secret':'DB-SECRET','medical':'raw sample'})
    g.client=httpx.AsyncClient(transport=httpx.MockTransport(failure),base_url='https://example.invalid')
    with pytest.raises(HTTPException) as exc:await g.rpc('healthbridge_read',{'p_kind':'metric'})
    assert exc.value.status_code==503 and 'SECRET' not in exc.value.detail
    await g.close()

@pytest.fixture
def anyio_backend():return 'asyncio'


def test_validation_diagnostics_hide_values_and_unknown_keys(setup):
    c,s=setup;p=sample();p['SECRET_FIELD_NAME']='SECRET_VALUE'
    r=c.post('/api/apple-health/sync',json=p,headers=U)
    assert r.status_code==422
    assert r.json()['errors']==[{'field':'body.<field>','code':'extra_forbidden'}]
    assert 'SECRET' not in r.text and not s.calls


@pytest.mark.parametrize('version',[1,2])
def test_supported_schema_versions_are_preserved(setup,version):
    c,s=setup;p=sample();p['schema_version']=version
    assert c.post('/api/apple-health/sync',headers=U,json=p).status_code==200
    assert s.calls[-1][1]['p_batch']['schema_version']==version

def test_unknown_schema_version_is_rejected(setup):
    c,s=setup;p=sample();p['schema_version']=3
    assert c.post('/api/apple-health/sync',headers=U,json=p).status_code==422
    assert not s.calls

def test_actual_swift_normalizer_payload(setup):
    from pathlib import Path
    p=json.loads((Path(__file__).resolve().parents[2]/'validation/swift-native-v2.json').read_text())
    c,s=setup
    assert p['schema_version']==2
    r=c.post('/api/apple-health/sync',headers=U,json=p)
    assert r.status_code==200
    assert s.calls[-1][1]['p_batch']['schema_version']==2
    assert s.calls[-1][1]['p_batch']['metrics'][0]['value']==.975

def test_unmodified_upstream_swift_contract(setup):
    from pathlib import Path
    c, storage = setup
    p = json.loads((Path(__file__).resolve().parents[2] / 'validation/upstream-swift-v2.json').read_text())
    r = c.post('/api/apple-health/sync', headers=U, json=p)
    assert r.status_code == 200
    received = storage.calls[0][1]['p_batch']
    assert received['schema_version'] == 2
    from datetime import datetime
    for actual, expected in zip(received['metrics'], p['metrics'], strict=True):
        for key, value in expected.items():
            if key in ('start_at', 'end_at'):
                assert datetime.fromisoformat(actual[key]) == datetime.fromisoformat(value)
            else:
                assert actual[key] == value
    oxygen = next(m for m in received['metrics'] if m['type'] == 'oxygen_saturation')
    assert oxygen['value'] == 0.975 and oxygen['unit'] == 'percent'
