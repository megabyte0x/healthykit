"""Upstream routes + CloudBase port, with synthetic data and no network calls."""
import copy
from datetime import datetime
from fastapi.testclient import TestClient
from app import create_app, Settings
from backend.repository import summarize_metric_items
from backend.schemas import HealthMetricOut
from test_api import sample, U, R

class Gateway:
    def __init__(self):
        self.calls=[]
        at='2026-10-18T01:00:00Z'
        base={**sample()['metrics'][0], 'device_id':'test-phone','export_id':'11111111-1111-4111-8111-111111111111',
              'timezone':'Asia/Shanghai','local_date':'2026-10-18','start_at':at,'end_at':at}
        self.items=[{**base,'id':f'healthkit:{n:04}', 'value':.97+n*.000001} for n in range(501)]
    async def rpc(self,name,args):
        self.calls.append((name,args))
        if name=='healthbridge_catalog':
            return {'metric_types':['oxygen_saturation'],'activity_types':[],
                    'timezones':['Asia/Shanghai'],'devices':[{'device_id':'test-phone','label':None}]}
        items=self.items if args['p_kind']=='metric' else []
        if args.get('p_device') and args['p_device']!='test-phone':items=[]
        off,limit=args.get('p_offset',0),args.get('p_limit',100)
        return {'items':items[off:off+limit],'page':{'limit':limit,'offset':off,'has_more':off+limit<len(items)}}

def test_official_digest_reuses_upstream_summaries_across_pages():
    storage=Gateway()
    with TestClient(create_app(Settings('https://example.invalid','db','u'*43,'r'*43),storage)) as client:
        data=client.get('/api/agent/health-data',headers=R,params={'limit':2}).json()
        assert data['workspace_id']=='self_hosted' and len(data['metrics'])==2 and data['page']['has_more']
        assert data['catalog']['metric_types']==['oxygen_saturation']
        expected=summarize_metric_items([HealthMetricOut.model_validate(m) for m in storage.items])
        assert data['metric_daily_summaries']==[m.model_dump(mode='json') for m in expected]
        assert data['metric_daily_summaries'][0]['sample_count']==501
        assert any(a.get('p_offset')==500 for n,a in storage.calls if n=='healthbridge_read_official')

def test_official_read_routes_preserve_read_only_token_and_device_filter():
    storage=Gateway()
    with TestClient(create_app(Settings('https://example.invalid','db','u'*43,'r'*43),storage)) as client:
        for route in ['metrics','workouts','syncs']:
            url='/api/apple-health/'+route
            assert client.get(url,headers=U).status_code==403
            assert client.get(url,headers=R).status_code==200
        assert client.get('/api/apple-health/metrics',headers=R,params={'device_id':'other'}).json()['items']==[]
        assert client.get('/api/agent/metrics',headers=R,params={'from':'2026-10-18T00:00:00'}).status_code==422
        assert client.post('/api/hosted/workspaces',json={}).status_code==404

def test_http_handlers_come_from_upstream_backend():
    app=create_app(Settings('https://example.invalid','db','u'*43,'r'*43),Gateway())
    for route in app.routes:
        if getattr(route,'path','').startswith('/api/'):
            assert route.endpoint.__module__=='backend.app'

def test_mcp_reads_share_official_storage_port():
    import asyncio
    from official_storage import CloudBaseStorage, OfficialMCPGateway
    storage=Gateway()
    adapter=CloudBaseStorage(storage,Settings('https://example.invalid','db','u'*43,'r'*43))
    result=asyncio.run(OfficialMCPGateway(adapter).rpc('healthbridge_read',
        {'p_kind':'metric','p_type':'oxygen_saturation','p_limit':2,'p_offset':0}))
    assert result['workspace_id']=='self_hosted' and len(result['items'])==2
    assert storage.calls[0][0]=='healthbridge_read_official'
    assert storage.calls[0][1]['p_type']=='oxygen_saturation'
