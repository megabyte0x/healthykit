# HealthSync TestFlight Access

This Next.js app collects HealthSync TestFlight access requests.

Public App Store URLs:

- Privacy policy: https://healthysync.megabyte.sh/privacy
- Support: https://healthysync.megabyte.sh/support

## Run locally

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

Local submissions are appended to `web/data/testflight-requests.jsonl`, which is ignored by git.

## Production storage

Production must use durable storage. The API chooses storage in this order:

1. `TESTFLIGHT_REQUEST_WEBHOOK_URL`, if set.
2. Vercel Blob, when `BLOB_READ_WRITE_TOKEN` or Vercel Blob OIDC env vars are present.
3. Local JSONL only outside Vercel.

On Vercel, requests fail with a `502` if neither webhook nor Blob storage is configured. This prevents production submissions from being written to ephemeral serverless disk.

## Vercel setup

```bash
vercel blob create-store healthsync-testflight-requests \
  --access private \
  --yes \
  --environment production \
  --environment preview \
  --environment development \
  --scope megabytes-projects
vercel env add TESTFLIGHT_ADMIN_TOKEN production preview development --sensitive --scope megabytes-projects
vercel env add NEXT_PUBLIC_SITE_URL production preview development --scope megabytes-projects
vercel env pull .env.local --yes --scope megabytes-projects
vercel deploy --prod --scope megabytes-projects
```

Set `NEXT_PUBLIC_SITE_URL` to the canonical public URL. If using an existing Blob store instead of `create-store`, make sure `BLOB_READ_WRITE_TOKEN` or the Vercel Blob OIDC env vars are connected to the project before deploying.

## Operating the list

Requests can be exported from the protected admin endpoint:

```bash
SITE_URL=https://healthysync.megabyte.sh \
TESTFLIGHT_ADMIN_TOKEN=... \
npm run export:requests
```

The endpoint also supports JSON:

```bash
curl -H "Authorization: Bearer $TESTFLIGHT_ADMIN_TOKEN" \
  "https://healthysync.megabyte.sh/api/access-requests"
```

## Health check

```bash
SITE_URL=https://healthysync.megabyte.sh npm run health
```

The health endpoint reports `storage: "vercel-blob"` when production storage is correctly configured.
