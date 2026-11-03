"""Persistent adapter for FastMCP OAuth; all entry values must be encrypted upstream."""
from datetime import datetime
from hashlib import sha256
from key_value.aio.stores.base import BaseStore, ManagedEntry


class CloudBaseOAuthStore(BaseStore):
    def __init__(self, gateway):
        super().__init__(stable_api=True)
        self.gateway = gateway

    async def _rpc(self, action, collection, key, **kwargs):
        return await self.gateway.rpc('healthbridge_oauth_kv', {
            'p_action': action, 'p_collection': collection,
            'p_key': sha256(key.encode()).hexdigest(), **kwargs,
        })

    async def _get_managed_entry(self, *, collection, key):
        result = await self._rpc('get', collection, key)
        entry = result.get('entry')
        if entry is None:
            return None
        return ManagedEntry(
            value=entry['value'],
            created_at=datetime.fromisoformat(entry['created_at']) if entry.get('created_at') else None,
            expires_at=datetime.fromisoformat(entry['expires_at']) if entry.get('expires_at') else None,
        )

    async def _put_managed_entry(self, *, collection, key, managed_entry):
        await self._rpc('put', collection, key, p_entry={
            'value': managed_entry.value_as_dict,
            'created_at': managed_entry.created_at_isoformat,
            'expires_at': managed_entry.expires_at_isoformat,
        }, p_expires_at=managed_entry.expires_at_isoformat)

    async def _delete_managed_entry(self, *, collection, key):
        return (await self._rpc('delete', collection, key)).get('deleted', False)
