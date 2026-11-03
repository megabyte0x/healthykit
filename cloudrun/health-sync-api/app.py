"""Health-only API. PG access is through fixed CloudBase RPCs; no TCP/ORM or shared app migrations."""
from contextlib import asynccontextmanager
from dataclasses import dataclass
import hashlib,json,os,secrets,logging
import httpx
from fastapi import FastAPI,Depends,Header,HTTPException,Query,Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import AwareDatetime, ValidationError
from models import Batch

@dataclass(frozen=True)
class Settings:
    base: str
    db_key: str
    upload_token: str
    read_token: str

    @classmethod
    def from_env(cls):
        env=os.environ['CLOUDBASE_ENV_ID']
        if not env or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in env):
            raise RuntimeError('Invalid environment ID')
        obj=cls('https://'+env+'.api.tcloudbasegateway.com',os.environ['CLOUDBASE_APIKEY'],os.environ['API_TOKEN'],os.environ['READ_TOKEN'])
        if min(len(obj.upload_token),len(obj.read_token))<32 or obj.upload_token==obj.read_token or not obj.db_key:
            raise RuntimeError('Separate server-side credentials are required')
        return obj

class Gateway:
    def __init__(self,settings):
        self.client=httpx.AsyncClient(base_url=settings.base,headers={'Authorization':'Bearer '+settings.db_key},timeout=httpx.Timeout(20,connect=5),follow_redirects=False,trust_env=False)

    async def rpc(self,name,args):
        try:
            response=await self.client.post('/v1/rdb/rest/rpc/'+name,json=args)
        except httpx.TransportError:
            raise HTTPException(503,'Storage temporarily unavailable') from None
        if response.status_code==409:
            raise HTTPException(409,'Export ID conflicts with an existing batch')
        if response.status_code!=200:
            raise HTTPException(503,'Storage temporarily unavailable')
        try: data=response.json()
        except ValueError: raise HTTPException(503,'Invalid storage response') from None
        if not isinstance(data,dict): raise HTTPException(503,'Invalid storage response')
        return data

    async def close(self):await self.client.aclose()

class BodyLimit:
    def __init__(self,app):self.app=app
    async def __call__(self,scope,receive,send):
        if scope['type']!='http':return await self.app(scope,receive,send)
        size=0
        async def limited():
            nonlocal size
            msg=await receive()
            size+=len(msg.get('body',b''))
            if size>4*1024*1024:raise HTTPException(413,'Payload too large')
            return msg
        await self.app(scope,limited,send)

def create_app(settings=None,gateway=None):
    settings=settings or Settings.from_env()
    storage=gateway or Gateway(settings)
    from official_storage import CloudBaseStorage, OfficialMCPGateway
    adapter = CloudBaseStorage(storage, settings)
    remote_bundle = None
    if os.environ.get('HEALTH_MCP_ENABLED') == '1':
        from remote_mcp import MCPSettings, create_remote_mcp
        remote_bundle = create_remote_mcp(OfficialMCPGateway(adapter), MCPSettings.from_env())
    @asynccontextmanager
    async def lifespan(app):
        try:
            if remote_bundle:
                async with remote_bundle[1].router.lifespan_context(remote_bundle[1]):
                    yield
            else:
                yield
        finally:
            if remote_bundle:
                await remote_bundle[2].client.aclose()
            if hasattr(storage,'close'):await storage.close()
    from backend.app import create_app as create_official_app
    from backend.config import Settings as OfficialSettings
    from official_storage import CloudBaseStorage
    official_settings = OfficialSettings(database_url='', api_token=settings.upload_token,
        token_hash_secret='unused-with-cloudbase-port', hosted_public_base_url='')
    async def validate_upload(request: Request):
        if request.url.path == '/api/apple-health/sync':
            adapter.resolve_auth(request.headers.get('Authorization'), 'ingest')
            try:
                Batch.model_validate(await request.json())
            except ValidationError as exc:
                raise RequestValidationError([{**e, 'loc': ('body', *e['loc'])} for e in exc.errors()]) from None
            except (ValueError, TypeError):
                raise HTTPException(422, 'Invalid request payload') from None
    app = create_official_app(official_settings, storage_adapter=adapter,
                              request_dependencies=[Depends(validate_upload)])
    app.router.lifespan_context = lifespan
    app.docs_url = app.redoc_url = app.openapi_url = None
    # Keep API docs disabled and preserve existing single-owner service exposure.
    app.router.routes = [route for route in app.router.routes
                         if getattr(route, 'path', '') not in ('/docs', '/redoc', '/openapi.json', '/docs/oauth2-redirect')
                         and not getattr(route, 'path', '').startswith('/api/hosted/')]
    app.add_middleware(BodyLimit)

    @app.exception_handler(RequestValidationError)
    async def invalid(request,exc):
        # Never include validation input, values, exception context, or unknown field names.
        allowed = {'body','query','metrics','workouts','deletions','date_range',
                   'device_id','export_id','generated_at','timezone','source','schema_version',
                   'id','type','value','unit','start_at','end_at','source_name','source_bundle_id',
                   'metadata','activity_type','duration_seconds','total_energy_kcal',
                   'active_energy_kcal','distance_meters','start','end','kind','limit','offset','from','to'}
        errors = [{'field': '.'.join(str(v) if isinstance(v,int) or v in allowed else '<field>'
                                    for v in e['loc']), 'code': e['type']}
                  for e in exc.errors()[:10]]
        logging.getLogger('healthbridge.validation').warning('Rejected request fields: %s', json.dumps(errors))
        return JSONResponse({'detail':'Invalid request payload','errors':errors},status_code=422)

    @app.get('/ready')
    async def ready():
        await storage.rpc('healthbridge_read',{'p_kind':'metric','p_limit':1})
        return {'ok':True}

    if remote_bundle:
        app.mount('/', remote_bundle[1])
    return app
