# chore(migration): retire the legacy Supabase endpoint

Cloudflare Workers/D1 already owns hosted HealthSync data and authentication. The remaining HealthSync dependency is the old Supabase-owned URL, which forwards to the new API. Removing it safely requires an app release and URL updates in independently configured agents. The iPhone app cannot rewrite third-party configuration remotely.

## User actions

| User or integration | Required action | Preserved state |
| --- | --- | --- |
| Hosted iPhone app | Install the migration release and open it once; automatic updates may install it without a manual download. | Same workspace, Keychain tokens, permissions, device ID, HealthKit anchors and queued uploads. |
| Agent with a complete saved endpoint | Replace only the legacy base with `https://api.healthysync.app`; retain the existing `/api/agent/...` route and query filters. | Same bearer token, workspace and response schema. |
| OpenAPI action or tool with base URL and paths | Use `https://api.healthysync.app` as the base URL, removing `/functions/v1/healthsync`; retain `/api/agent/...` paths. | Same private bearer credential. |
| Script or automation | Update `AGENT_ENDPOINT` or the HTTP node URL; test a read against the existing workspace. | Same Authorization header and filters. |
| Unrelated self-hosted installation | No migration action. | Its backend settings and credentials remain unchanged. |

No user needs to reset hosted storage, refresh/rotate tokens, reinstall the app, reauthorize Apple Health, or upload their entire history again for this URL change. App updates do not update an external agent's saved URL. Users returning with an old app after retirement must update before it can connect.

The official legacy base is `https://dtzydnjnqkruxaacgkio.supabase.co/functions/v1/healthsync`. The new base is `https://api.healthysync.app`. The agent paths `/api/agent/health-data`, `/metrics`, `/workouts`, and `/syncs` are preserved. The agent endpoint is ordinary bearer-authenticated HTTP, not an MCP server URL.

## Upgrade and recovery flows

| Flow | Expected behavior | Verification |
| --- | --- | --- |
| U1: updated app loads old hosted settings | Only recognized official URLs move; workspace, selection, schedule and permission state are retained and the change persists. | LocalStore upgrade fixture, reopen, device/anchor/queue equality. |
| U2: official legacy base was pasted in custom-backend mode | The known service moves without changing mode or the existing upload credential. | Request URL and Authorization assertion. |
| U3: a different server, project, path, port or embedded userinfo is configured | Leave the address unchanged; do not redirect credentials to a different service. | Unrelated/ambiguous URL fixtures. |
| U4: SQLite refuses the migration write | Use the migrated settings in memory; leave the original stored row intact and retry persistence on next load. Do not fall back to provisioning/reset. | Injected UPDATE failure, retained workspace and successful later reload. |
| U5: agent is already configured outside the app | Its owner changes only the URL/base URL and verifies the same workspace with the same token. | Public migration instructions plus owner verification; app tests cannot certify third-party configuration. |
| U6: old apps/agents are still active | Keep the bridge available. A rollout date or quiet traffic window alone does not prove dormant clients have migrated. | Legacy invocation aggregates, release adoption and known integration confirmations. |
| U7: retirement becomes safe | Take and restore-verify a fresh D1 export, retain independent HMAC-secret recovery, then decommission only the intended project after the explicit retention/billing decision. | Data/secret verification, absence of required legacy traffic, confirmed project identity and operator approval. |

## Release and adoption

The public App Store version checked on 8 November 2026 is 1.0.2. Prepare the migration as 1.0.3 with the existing bundle ID and signing team; a differently signed app or reinstall is not a migration path. The repository's manual TestFlight workflow can test, archive and upload the candidate using existing App Store Connect secrets. A TestFlight upload does not update public App Store users: the build must pass App Review and be released for them.

Version 1.0.3 build 35, from commit `8035b9c`, was uploaded successfully to App Store Connect on 8 November 2026. The local archive used the existing development identity and Apple cloud-managed distribution signing after the fresh CI runner hit Apple's development-certificate limit. The exported App Store package passed signature, app/team identity, default Keychain group and HealthKit/background-delivery entitlement checks. This records upload only; processing, TestFlight availability and public release must be checked separately.

Publish the shared HTML/Markdown agent-access guide and include its URL in release notes. It must show the old/new URL, preservation of the bearer credential and the warning against reset/token rotation. Do not send migration messages to users through email or other services without separate explicit authorization.

After rollout, inspect aggregate legacy-function requests and old app versions. Keep identifiers, tokens and health values out of rollout reports. Confirm known agent owners have moved. Choose a retirement date only with this evidence; users who never update cannot be made compatible with deleting a third-party-owned hostname. A zero-breakage guarantee for every dormant client is incompatible with deleting that hostname before those clients update.

## Remove the remaining Supabase resources

1. Verify the actual next billing date in the organization billing page; it has not been verified by this runbook. Complete app release and agent updates ahead of that date rather than assuming the next month is free.
2. Verify current D1 health, accepted uploads and agent reads. Take a new native D1 export and restore it, including writes accepted after the original cutover. Retain the original PostgreSQL archive according to the owner's retention decision.
3. Preserve Cloudflare's exact `TOKEN_HASH_SECRET` and protected recovery copy. Its bytes originated from a Supabase reserved secret but are now an independent HMAC key. Deleting Supabase does not require rotating this key; changing it would invalidate existing tokens.
4. Confirm that HealthSync no longer uses the old project for Auth, Storage, Realtime, functions, jobs or secrets. The original cutover found no Auth users, Storage objects or Vault secrets, but recheck current state before deletion.
5. Decommission the HealthSync bridge/project only after adoption evidence and a concrete deletion/retention approval. Deleting the project is irreversible and removes its data, backups, functions, hostname and API credentials. The frozen PostgreSQL copy is not a current replacement for D1.
6. Remove the Pro subscription only after checking the unrelated `still-reading` project in the same organization. Supabase billing is organization-wide and downgrades are immediate. HealthSync's migration does not authorize deleting/migrating that other project. Removing Supabase from the entire account would require separately migrating or retiring it too.

Do not pause/delete the old project or downgrade as an incidental app update. Current status and executed deployment evidence remain in [the cutover runbook](cloudflare-hosted.md). Current source files and backups can be retained offline after decommissioning; they do not create a running Supabase dependency.

References: [Supabase subscription changes](https://supabase.com/docs/guides/platform/manage-your-subscription), [project deletion](https://supabase.com/docs/guides/platform/delete-project).
