# HealthSync on Tencent CloudBase

This deployment runs the upstream HealthSync API with a CloudBase PostgreSQL storage adapter in a single self-hosted workspace. The optional remote MCP server provides read-only access through Casdoor OAuth.

1. Create a dedicated CloudBase PostgreSQL environment. Apply the SQL files in `cloudbase/migrations/` in filename order using an administrative migration connection.
2. From the repository root run `python3 scripts/prepare_cloudrun_context.py /tmp/healthsync-cloudrun`. Deploy that directory as a CloudBase Run container on port 8080 with a readiness probe at `/ready`.
3. Configure `CLOUDBASE_ENV_ID`, `CLOUDBASE_APIKEY`, `API_TOKEN` and `READ_TOKEN` as runtime secrets. The CloudBase key must have service-role access to the RPCs. Generate distinct random upload and read tokens. Give only the upload token to the iOS client.
4. For remote MCP, set `HEALTH_MCP_ENABLED=1` and `HEALTH_PUBLIC_URL` to the externally reachable HTTPS base URL. Prefer a dedicated hostname with root routing and ensure the proxy forwards OAuth discovery URLs and preserves authentication headers.
5. Create a confidential Casdoor application with authorization-code and refresh-token grants and scopes `openid profile offline_access`. Register the exact redirect URI `<HEALTH_PUBLIC_URL>/auth/callback`. Set `CASDOOR_ISSUER`, `CASDOOR_CLIENT_ID`, `CASDOOR_CLIENT_SECRET`, `CASDOOR_ALLOWED_ORG` and `CASDOOR_ALLOWED_USER`. The allowlist identifies the sole account authorized to query the workspace.
6. Set `MCP_SIGNING_KEY` to a random secret from `openssl rand -hex 32`. Generate `MCP_STORAGE_KEY` with `python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'`. Keep both stable across deployments. Connect the MCP client to `<HEALTH_PUBLIC_URL>/mcp`.

Check `/ready`, perform a synthetic sync and verify that the upload token cannot read samples. With MCP enabled, check that anonymous requests receive an OAuth challenge and that the allowed Casdoor account can query the synthetic samples.

Run the synthetic tests from the repository root after installing both backend and CloudRun requirements and pytest:

```sh
python -m pytest -q Tests/backend cloudrun/health-sync-api
```
