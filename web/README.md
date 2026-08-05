# HealthSync website

This Next.js app is the public website for HealthSync, an iPhone app that syncs selected Apple
Health data to a private backend.

Public URLs:

- App Store: https://apps.apple.com/in/app/healthysync/id6776575569
- Privacy policy: https://healthysync.megabyte.sh/privacy
- Support: https://healthysync.megabyte.sh/support

## Run locally

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Vercel setup

```bash
vercel env add NEXT_PUBLIC_SITE_URL production preview development --scope megabytes-projects
vercel deploy --prod --scope megabytes-projects
```

Set `NEXT_PUBLIC_SITE_URL` to the canonical public URL.

## Health check

```bash
SITE_URL=https://healthysync.megabyte.sh npm run health
```

The health endpoint returns the deployed site status.
