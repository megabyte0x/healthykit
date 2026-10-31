import { absoluteUrl } from "./site";

export type DocBlock =
  | { kind: "paragraph"; text: string }
  | { kind: "list"; items: string[] }
  | { kind: "code"; language: string; text: string }
  | { kind: "link"; label: string; href: string };

export type Guide = {
  slug: string;
  title: string;
  description: string;
  sections: { id: string; title: string; blocks: DocBlock[] }[];
};

export const guides: Guide[] = [
  {
    slug: "getting-started",
    title: "Getting started",
    description: "Choose hosted storage or your own server, connect Apple Health, and verify your first sync.",
    sections: [
      { id: "choose-storage", title: "1. Choose where your data goes", blocks: [
        { kind: "paragraph", text: "HealthSync reads Apple Health on your iPhone after you grant permission. You can use the app's hosted HealthSync storage or run the open source FastAPI backend with Postgres. A managed Postgres database alone is not a sync endpoint: you still need to run the API." },
        { kind: "list", items: ["Hosted HealthSync storage: the app provisions a private workspace. No server setup is needed.", "Your own backend: you operate the API, database, HTTPS, backups, and updates. Xcode is not required to run the server."] },
        { kind: "link", label: "Set up your own server", href: "/docs/self-hosting" }
      ] },
      { id: "connect", title: "2. Connect Apple Health", blocks: [
        { kind: "paragraph", text: "Install HealthSync on your iPhone and tap Continue. The default setup creates hosted storage and asks you to review Apple Health read permissions. Choose the categories you want to sync." },
        { kind: "paragraph", text: "To use your own server, open Settings, choose your own backend, and enter its reachable base URL and auth token. Enter the base URL without /api/apple-health/sync; the app adds that path. For the standard self-hosted server, the auth token is API_TOKEN." },
        { kind: "link", label: "Download HealthSync", href: "https://apps.apple.com/in/app/healthysync/id6776575569" }
      ] },
      { id: "first-sync", title: "3. Verify a real sync", blocks: [
        { kind: "list", items: ["Choose a category that has samples in Apple Health, then run Sync last 24 hours.", "Review Sync Logs for a successful upload. If the samples are older, use Backfill date range.", "For your own backend, fetch /api/apple-health/metrics or /api/apple-health/workouts with API_TOKEN. For hosted storage, use the private agent endpoint and read-only agent token.", "An empty response can mean there are no permitted samples in the selected date range. A successful /health response only confirms the API is responding; a successful upload and fetch confirm storage works."] },
        { kind: "link", label: "Read your data with an agent", href: "/docs/agent-access" }
      ] },
      { id: "background-sync", title: "4. Set your sync preferences", blocks: [
        { kind: "paragraph", text: "In Settings, select data types and sync frequency. Background delivery is best effort: iOS controls when the app runs. Low Power Mode, a locked phone, rebooting, or force-quitting can delay sync. Manual sync and backfill are the reliable ways to request an update." },
        { kind: "link", label: "Troubleshoot sync and server issues", href: "/docs/operations#troubleshooting" }
      ] }
    ]
  },
  {
    slug: "self-hosting",
    title: "Server setup",
    description: "Run the HealthSync API and Postgres with Docker, or connect the API to a managed database.",
    sections: [
      { id: "requirements", title: "1. Get the server code", blocks: [
        { kind: "paragraph", text: "You need Git, Python 3.11 or newer for the token helper, and Docker with Compose. Docker Desktop works for local testing; a Linux server with Docker works for production. Run the following commands from the repository root." },
        { kind: "code", language: "bash", text: "git clone https://github.com/megabyte0x/healthykit.git\ncd healthykit\ncp .env.example .env\npython3 -m backend.scripts.generate_token\npython3 -m backend.scripts.generate_token" }
      ] },
      { id: "configure", title: "2. Configure secrets", blocks: [
        { kind: "paragraph", text: "Edit .env before starting the server. Replace POSTGRES_PASSWORD with a long random password, API_TOKEN with the first generated token, and TOKEN_HASH_SECRET with the second. Use a URL-safe database password (letters and digits are sufficient) because Compose inserts it into the database connection URL. Keep .env private and uncommitted." },
        { kind: "list", items: ["API_TOKEN: the credential used by the standard self-hosted app and read APIs. It allows uploads as well as reads.", "TOKEN_HASH_SECRET: a separate HMAC secret required by the API. Preserve it across restarts and upgrades; changing it invalidates existing hosted tokens.", "POSTGRES_DB and POSTGRES_USER: default to healthsync.", "API_HOST_PORT: defaults to 8080. POSTGRES_HOST_PORT: defaults to 15432.", "HOSTED_PROVISIONING_ENABLED: leave false for the standard self-hosted setup."] }
      ] },
      { id: "start", title: "3. Start and check the API", blocks: [
        { kind: "code", language: "bash", text: "docker compose config --quiet\ndocker compose up --build -d\ndocker compose ps\ncurl --fail http://127.0.0.1:8080/health" },
        { kind: "paragraph", text: "The health endpoint should return {\"ok\":true}. The API container runs database migrations before starting FastAPI. Postgres data is stored in the healthsync-postgres-data named volume and survives normal container restarts. Do not run docker compose down -v unless you intend to delete the database." },
        { kind: "paragraph", text: "To verify an authenticated database read, set API_TOKEN in your shell to the value saved in .env, then run:" },
        { kind: "code", language: "bash", text: 'curl --fail -H "Authorization: Bearer $API_TOKEN" \\\n  "http://127.0.0.1:8080/api/apple-health/metrics?limit=10"' },
        { kind: "paragraph", text: "An empty items array is expected before your first upload. If you change API_HOST_PORT, use that port in these checks." }
      ] },
      { id: "https", title: "4. Make the API reachable over HTTPS", blocks: [
        { kind: "paragraph", text: "For production, point a domain at your server and place the API behind an HTTPS reverse proxy. For example, if Caddy runs directly on the same server, add the following site block to its configuration and replace api.example.com with your domain. Allow the proxy's HTTP/HTTPS ports through your firewall and ensure certificate issuance can reach the server." },
        { kind: "code", language: "text", text: "api.example.com {\n    reverse_proxy 127.0.0.1:8080\n}" },
        { kind: "paragraph", text: "The supplied Compose file publishes both database and API ports on all interfaces. With a proxy running on the host, change the db ports entry to the first line below and the api ports entry to the second line. Keep Postgres private. A proxy running in a container needs a shared Docker network and the api:8080 service address instead of host loopback." },
        { kind: "code", language: "yaml", text: '"127.0.0.1:${POSTGRES_HOST_PORT:-15432}:5432"\n"127.0.0.1:${API_HOST_PORT:-8080}:8080"' },
        { kind: "paragraph", text: "Apply port changes with docker compose up -d. Check https://api.example.com/health from a device outside the server, then repeat an authenticated read through HTTPS." }
      ] },
      { id: "iphone", title: "5. Connect your iPhone", blocks: [
        { kind: "list", items: ["In HealthSync Settings, choose your own backend.", "Set the backend URL to your HTTPS base URL, such as https://api.example.com, and the auth token to API_TOKEN.", "Grant Apple Health read permissions, run Sync last 24 hours, and inspect Sync Logs.", "Repeat the metrics or workouts fetch after uploading to confirm the records were persisted.", "For same-Wi-Fi testing only, use http://<server-lan-ip>:8080 and allow iOS Local Network access. 127.0.0.1 on an iPhone refers to the phone itself. The simulator can use http://127.0.0.1:8080 when the server runs on its Mac."] },
        { kind: "link", label: "Back up and maintain your server", href: "/docs/operations" }
      ] },
      { id: "managed-postgres", title: "Alternative: use a managed Postgres database", blocks: [
        { kind: "paragraph", text: "You can run the same FastAPI service against a managed Postgres database. Obtain the provider's connection string and required TLS settings. Set DATABASE_URL explicitly where the API runs; the supplied Compose stack constructs its own local database URL and does not use this alternative automatically." },
        { kind: "code", language: "bash", text: "python3 -m venv .venv\nsource .venv/bin/activate\npip install -r backend/requirements.txt\nexport DATABASE_URL='postgresql+psycopg://USER:PASSWORD@HOST:PORT/DATABASE'\nexport API_TOKEN=\"$(python3 -m backend.scripts.generate_token)\"\nexport TOKEN_HASH_SECRET=\"$(python3 -m backend.scripts.generate_token)\"\nalembic upgrade head\nuvicorn backend.main:app --host 0.0.0.0 --port 8080" },
        { kind: "paragraph", text: "Replace the connection-string placeholders, percent-encode special characters in credentials, and apply the provider's TLS requirements. Save the generated secrets securely and configure your service manager to reuse them on restart. Put the API behind HTTPS as above. The iPhone receives only the API base URL and API_TOKEN; database credentials stay on the server." },
        { kind: "link", label: "Optional: provision workspaces with read-only agent tokens", href: "/docs/agent-access#your-own-service" }
      ] }
    ]
  },
  {
    slug: "operations",
    title: "Server operations",
    description: "Back up Postgres, apply updates, manage credentials, and troubleshoot sync failures.",
    sections: [
      { id: "backups", title: "Back up the database and configuration", blocks: [
        { kind: "paragraph", text: "For the Docker stack, create a Postgres custom-format backup from the repository root. Choose a new filename for each backup so you do not overwrite the previous one." },
        { kind: "code", language: "bash", text: 'docker compose exec -T db sh -c \'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc\' > healthsync-backup.dump\ndocker compose exec -T db pg_restore --list < healthsync-backup.dump' },
        { kind: "paragraph", text: "The archive listing confirms that the dump is readable, but it does not prove recovery works. Test a restore into a separate, empty database in an isolated environment using pg_restore with --exit-on-error, then verify expected tables and record counts. Never test a restore over your live database." },
        { kind: "paragraph", text: "Keep encrypted backups off the server and retain a secure copy of .env, especially TOKEN_HASH_SECRET, along with the deployed Git revision. Database dumps contain private health data. For managed Postgres, also configure and test the provider's backup and restore process. A Docker volume alone is not a backup." }
      ] },
      { id: "updates", title: "Apply updates", blocks: [
        { kind: "paragraph", text: "Back up the database and configuration first, record the current Git revision, and review the incoming changes. From your deployment checkout, run:" },
        { kind: "code", language: "bash", text: "git rev-parse HEAD\ngit pull --ff-only\ndocker compose up --build -d\ndocker compose ps\ncurl --fail http://127.0.0.1:8080/health" },
        { kind: "paragraph", text: "Keep your existing secrets. The rebuilt API container applies migrations on startup. Verify an authenticated read and a real iPhone upload after updating. For manual deployments, update dependencies, run alembic upgrade head, and restart your API service. Code rollback alone may not undo schema changes; plan database recovery before rolling back a migration." }
      ] },
      { id: "credentials", title: "Manage credentials", blocks: [
        { kind: "list", items: ["Self-hosted API_TOKEN: generate a replacement, update .env, run docker compose up -d api to recreate the service with the new environment, and update the iPhone and any trusted readers. Old credentials stop working when the new configuration takes effect.", "Hosted agent token: use Refresh read-only agent token in the app's Agent Access Details, then update your agent's credential store. Previous agent tokens for that workspace are revoked.", "TOKEN_HASH_SECRET: preserve it. Changing it makes existing hosted ingest and agent tokens unusable; it is not the routine way to rotate one token.", "Reset Hosted Storage deletes the current hosted workspace data when the saved token is valid, then creates a new workspace and credentials. Use agent-token refresh when only the agent credential needs replacement."] }
      ] },
      { id: "troubleshooting", title: "Troubleshoot connection and sync issues", blocks: [
        { kind: "list", items: ["API will not start: check that the three required secrets are set, run docker compose config --quiet, and inspect docker compose logs --tail=100 api db for startup or migration errors. Config output without --quiet can include secrets.", "401 response: supply Authorization: Bearer <token>. 403 response: check the token value and kind; an ingest token cannot read /api/agent/*, and a read-only agent token cannot upload.", "Phone cannot connect: verify DNS, HTTPS, firewall, and reachability from the phone. For local tests, use the server's LAN address and allow Local Network access.", "Successful sync but empty reads: confirm the app and reader use the same backend and workspace. Self-hosted API_TOKEN reads do not include hosted workspace data. Confirm you are running backend/, not the non-persistent backend_stub/.", "No new data: check Apple Health permissions, category selection, and date range. Try manual sync or backfill. Background sync timing is controlled by iOS.", "Uploads retry: inspect Sync Logs and server availability. Failed batches stay queued on the iPhone for later retries. Replayed record IDs are deduplicated; repeated uploads do not imply duplicate stored records."] },
        { kind: "link", label: "Contact support", href: "/support" }
      ] }
    ]
  },
  {
    slug: "agent-access",
    title: "Agent access",
    description: "Connect an HTTP-capable agent to your private health data using the correct endpoint and credential.",
    sections: [
      { id: "hosted-credentials", title: "1. Copy your hosted agent credentials", blocks: [
        { kind: "paragraph", text: "With hosted HealthSync storage selected, open Settings → Agent Access Details. Use Copy agent endpoint and Copy read-only agent token. If these controls are missing, finish creating hosted storage first. Upload some Apple Health data before expecting records in the response." },
        { kind: "paragraph", text: "Save the token in your agent tool's private credential store. Give it only the copied endpoint and agent token. Do not give agents your ingest token, API_TOKEN, database connection string, or database service credentials. Anyone with the agent token can read the workspace's synced health data." }
      ] },
      { id: "request", title: "2. Make an authenticated request", blocks: [
        { kind: "paragraph", text: "Set AGENT_ENDPOINT to the complete endpoint copied from the app, and AGENT_TOKEN to its read-only token. Preserve the full URL, including any hosting path prefix; do not append /api/agent/health-data again." },
        { kind: "code", language: "bash", text: 'curl --fail --get "$AGENT_ENDPOINT" \\\n  -H "Authorization: Bearer $AGENT_TOKEN" \\\n  --data-urlencode "limit=100" \\\n  --data-urlencode "offset=0"' },
        { kind: "paragraph", text: "Configure an HTTP-capable agent tool to send GET requests to that endpoint with the Authorization header. The endpoint returns JSON over HTTP; it is not an MCP server URL. Confirm your tool supports custom bearer-authenticated HTTP requests." }
      ] },
      { id: "response", title: "3. Read and paginate the response", blocks: [
        { kind: "list", items: ["The combined endpoint returns agent_schema_version, workspace_id, range, page, catalog, metrics, workouts, syncs, metric_daily_summaries, and workout_daily_summaries.", "Raw records include timezone and local_date fields when available. Use them when interpreting a user's calendar days.", "Pagination defaults to 100 records per collection; limit accepts 1–500 and offset starts at 0. When page.has_more is true, request the next page by adding page.limit to page.offset. Continue until has_more is false.", "Records are sorted newest first in a stable order. Deduplicate imports on device_id and id.", "Every response includes the workspace_id of the agent token, even when empty.", "The combined endpoint paginates metrics, workouts, and syncs independently using the same offset. Daily summaries describe the full filtered range and repeat across pages; do not add them together across responses.", "Use from and to with timezone-aware ISO 8601 timestamps to filter a range. The type filter applies only to metrics. The range selects metrics/workouts starting at or after from and ending at or before to."] },
        { kind: "code", language: "bash", text: 'curl --fail --get "$AGENT_ENDPOINT" \\\n  -H "Authorization: Bearer $AGENT_TOKEN" \\\n  --data-urlencode "from=2026-10-01T00:00:00Z" \\\n  --data-urlencode "to=2026-10-08T00:00:00Z" \\\n  --data-urlencode "type=step_count" \\\n  --data-urlencode "limit=100" \\\n  --data-urlencode "offset=0"' },
        { kind: "paragraph", text: "For individual collections, replace the final /health-data path segment with /metrics, /workouts, or /syncs. These return workspace_id, items, and page. Metrics accept type, from, and to; workouts accept activity_type, from, and to; syncs accept device_id. All accept limit and offset and require the agent token." },
        { kind: "paragraph", text: "To fetch only some metric types, call /metrics once per type, for example type=resting_heart_rate. catalog.metric_types lists the types in your workspace." }
      ] },
      { id: "refresh", title: "4. Refresh or troubleshoot access", blocks: [
        { kind: "paragraph", text: "Use Refresh read-only agent token in Agent Access Details to replace the credential. Update your agent's saved token immediately; previous agent tokens for that workspace stop working. This preserves synced records. Reset Hosted Storage is a separate operation that can delete the current hosted data." },
        { kind: "paragraph", text: "A 401 means the bearer header is missing or empty. A 403 means the token is invalid, revoked, or the wrong kind. Empty arrays can mean no uploads yet or a filter outside the available dates. Sync from the iPhone and retry with the correct endpoint and date range." }
      ] },
      { id: "self-hosted-reads", title: "Standard self-hosted reads", blocks: [
        { kind: "paragraph", text: "A standard self-hosted installation uses API_TOKEN for GET /api/apple-health/metrics, /workouts, and /syncs under the same /api/apple-health prefix. These credentials also allow uploads, so this is not read-only agent isolation. Use them only with a trusted integration that should have that authority." },
        { kind: "code", language: "bash", text: 'curl --fail -H "Authorization: Bearer $API_TOKEN" \\\n  "https://api.example.com/api/apple-health/metrics?type=stepCount&limit=100&offset=0"' },
        { kind: "paragraph", text: "Self-hosted metric and workout filters use start_at and end_at rather than from and to. Metrics also accept type; workouts accept activity_type. All three endpoints accept device_id, limit, and offset. API_TOKEN is not accepted by /api/agent/*." }
      ] },
      { id: "your-own-service", title: "Optional: operate your own workspace service", blocks: [
        { kind: "paragraph", text: "The FastAPI backend can provision isolated workspaces with separate ingest and read-only agent tokens. On your existing HTTPS deployment, set HOSTED_PUBLIC_BASE_URL to its externally reachable base URL and HOSTED_PROVISIONING_ENABLED=true, then recreate or restart the API with that environment. DATABASE_URL, API_TOKEN, and TOKEN_HASH_SECRET remain required." },
        { kind: "paragraph", text: "Enabling provisioning exposes a workspace-creation endpoint without bearer authentication. Decide who should be able to reach it and apply appropriate access and rate controls before exposing your service. Leave provisioning disabled if you only need standard self-hosted storage." },
        { kind: "code", language: "bash", text: 'curl --fail -X POST "https://api.example.com/api/hosted/workspaces" \\\n  -H "Content-Type: application/json" \\\n  -d \'{"label":"Personal Health"}\'' },
        { kind: "paragraph", text: "The response contains workspace_id, backend_url, ingest_token, agent_endpoint, and agent_token. Save the credentials securely. In the app's own-backend settings, enter backend_url and ingest_token. Give your reader only agent_endpoint and agent_token. This creates a separate workspace; it does not move existing self-hosted records into it." },
        { kind: "paragraph", text: "For a workspace on your own service, POST /api/hosted/agent-token with Authorization: Bearer <ingest_token> returns a new agent token and revokes old agent tokens. Do this from a trusted administration tool; the app's hosted agent-refresh controls target its built-in hosted service." },
        { kind: "link", label: "Server setup prerequisites", href: "/docs/self-hosting" }
      ] }
    ]
  }
];

export function findGuide(slug: string) {
  return guides.find((guide) => guide.slug === slug);
}

export function guideMarkdown(guide: Guide) {
  const sections = guide.sections.map((section) => {
    const blocks = section.blocks.map((block) => {
      switch (block.kind) {
        case "paragraph": return block.text;
        case "list": return block.items.map((item) => `- ${item}`).join("\n");
        case "code": return `\`\`\`${block.language}\n${block.text}\n\`\`\``;
        case "link": return `[${block.label}](${block.href.startsWith("/") ? absoluteUrl(block.href) : block.href})`;
      }
    });
    return `## ${section.title}\n\n${blocks.join("\n\n")}`;
  });
  return `# ${guide.title}\n\n${guide.description}\n\n${sections.join("\n\n")}\n\n[All HealthSync documentation](${absoluteUrl("/docs")})\n`;
}
