"""Persistence/auth port for upstream backend.app; no duplicate HTTP/business routes."""
import hashlib
import json
import secrets
from anyio import from_thread
from fastapi import HTTPException
from pydantic import ValidationError
from backend.auth import AuthContext, bearer_token
from backend.schemas import (AgentCatalog, MetricListResponse, WorkoutListResponse,
                             SyncBatchListResponse, UploadResult)
from models import Batch


class CloudBaseStorage:
    workspace_id = 'self_hosted'

    def __init__(self, gateway, settings):
        self.gateway, self.settings = gateway, settings

    def session(self):
        # Upstream's dependency lifecycle expects close(); this port holds no SQL session.
        return self

    def close(self):
        pass

    def resolve_auth(self, authorization, kind):
        token = bearer_token(authorization)
        expected = self.settings.upload_token if kind == 'ingest' else self.settings.read_token
        if not secrets.compare_digest(token.encode(), expected.encode()):
            raise HTTPException(403, 'Token rejected')
        return AuthContext(workspace_id=self.workspace_id, token_kind=kind, self_hosted=True)

    def _owner(self, workspace_id):
        if workspace_id != self.workspace_id:
            raise HTTPException(403, 'Workspace unavailable')

    def _rpc(self, name, args):
        # Official routes are sync FastAPI worker threads; HTTP I/O stays on its event loop.
        return from_thread.run(self.gateway.rpc, name, args)

    def persist_sync_payload(self, db, payload, app_version, workspace_id):
        self._owner(workspace_id)
        try:
            data = Batch.model_validate(payload.model_dump(mode='json')).model_dump(mode='json')
        except ValidationError:
            raise HTTPException(422, 'Invalid request payload') from None
        digest = hashlib.sha256(json.dumps(data, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()).hexdigest()
        result = self._rpc('healthbridge_ingest', {'p_batch': data, 'p_hash': digest})
        if result.get('ok') is not True:
            raise HTTPException(503, 'Invalid storage acknowledgement')
        return UploadResult.model_validate(result)

    def _list(self, kind, response_model, *, workspace_id, device_id=None, metric_type=None,
              activity_type=None, start_at=None, end_at=None, limit=100, offset=0):
        self._owner(workspace_id)
        for value in (start_at, end_at):
            if value is not None and value.tzinfo is None:
                raise HTTPException(422, 'Timezone required')
        if start_at and end_at and start_at >= end_at:
            raise HTTPException(422, 'Ordered date range required')
        args = {'p_kind': kind, 'p_type': metric_type or activity_type, 'p_device': device_id,
                'p_from': start_at.isoformat() if start_at else None,
                'p_to': end_at.isoformat() if end_at else None, 'p_limit': limit, 'p_offset': offset}
        result = self._rpc('healthbridge_read_official', args)
        return response_model.model_validate({'workspace_id': workspace_id, **result})

    def list_metrics(self, db, **kwargs):
        return self._list('metric', MetricListResponse, **kwargs)

    def list_workouts(self, db, **kwargs):
        return self._list('workout', WorkoutListResponse, **kwargs)

    def list_sync_batches(self, db, **kwargs):
        return self._list('sync', SyncBatchListResponse, **kwargs)

    def _all(self, reader, kwargs):
        items, offset = [], 0
        while True:
            result = reader(self, **kwargs, limit=500, offset=offset)
            items.extend(result.items)
            if not result.page.has_more:
                return items
            if not result.items:
                raise HTTPException(503, 'Invalid storage pagination')
            offset += len(result.items)

    def list_metric_summary_items(self, db, **kwargs):
        return self._all(self.list_metrics, kwargs)

    def list_workout_summary_items(self, db, **kwargs):
        return self._all(self.list_workouts, kwargs)

    def get_agent_catalog(self, db, workspace_id):
        self._owner(workspace_id)
        return AgentCatalog.model_validate(self._rpc('healthbridge_catalog', {}))

    def provision_hosted_workspace(self, *args):
        raise HTTPException(403, 'Personal storage does not provision hosted workspaces')

    reset_hosted_workspace = provision_hosted_workspace
    rotate_hosted_agent_token = provision_hosted_workspace

class OfficialMCPGateway:
    """MCP reads use the same repository port as official HTTP routes; OAuth KV stays separate."""
    def __init__(self, adapter):
        self.adapter = adapter

    async def rpc(self, name, args):
        if name != 'healthbridge_read':
            return await self.adapter.gateway.rpc(name, args)
        from functools import partial
        from anyio import to_thread
        from datetime import datetime
        kind = args['p_kind']
        reader = {'metric': self.adapter.list_metrics, 'workout': self.adapter.list_workouts,
                  'sync': self.adapter.list_sync_batches}[kind]
        kwargs = {'workspace_id': self.adapter.workspace_id, 'limit': args.get('p_limit',100),
                  'offset': args.get('p_offset',0)}
        for key, target in [('p_from','start_at'),('p_to','end_at')]:
            kwargs[target] = datetime.fromisoformat(args[key]) if args.get(key) else None
        if kind == 'metric':kwargs['metric_type'] = args.get('p_type')
        if kind == 'workout':kwargs['activity_type'] = args.get('p_type')
        result = await to_thread.run_sync(partial(reader, self.adapter, **kwargs))
        return result.model_dump(mode='json')
