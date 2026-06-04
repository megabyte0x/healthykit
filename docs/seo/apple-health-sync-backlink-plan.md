# HealthSync Apple Health App Sync Backlink Plan

Date: 2026-06-05

Target site: https://web-megabytes-projects.vercel.app

Primary link target: https://web-megabytes-projects.vercel.app/apple-health-app-sync

Primary query family:

- Apple Health app sync
- sync Apple Health data
- HealthKit to API
- Apple Health to private backend
- self-hosted Apple Health sync

## Current Baseline

The live site returns `200` with `index, follow`, but the existing homepage metadata was thin: `HealthSync TestFlight Access` and `Request access to the HealthSync TestFlight app.` Search results for exact/current HealthSync wording showed App Store and competitor pages, not the Vercel site.

The SERP is already competitive and mixed-intent. Current visible results for Apple Health sync terms include:

- App Store listing for another `HealthSync` app that syncs Apple Health data to a personal dashboard API: https://apps.apple.com/am/app/healthsync/id6758778214
- Health Sync by appyhapps, which syncs among Apple Health, Garmin, Fitbit, Oura, Strava, and other services: https://apps.apple.com/it/app/health-sync-by-appyhapps/id6480174471?l=en-GB
- HealthSync.app product site for the appyhapps Health Sync product: https://healthsync.app/about/
- Health Webhook for iOS, a direct competitor for sending Apple Health data to webhook URLs: https://hcwebhook.com/ios
- HealthLog, a self-hosted health app with Apple Health iOS sync/TestFlight positioning: https://healthlog.dev/
- Health Auto Export, a mature Apple Health export app: https://apps.apple.com/us/app/health-auto-export-json-csv/id1115567069
- HealthFit, a mature Apple Health/workout sync app: https://apps.apple.com/us/app/healthfit/id1202650514
- Open Wearables Apple Health integration content for the API/SKD query class: https://openwearables.io/integrations/apple-health

## Guardrails

Do not buy backlinks, mass-post exact-match anchors, use private blog networks, or create doorway pages. Google's spam policy defines link spam as links created primarily to manipulate rankings, and violations can lead to lower rankings or removal from results: https://developers.google.com/search/docs/essentials/spam-policies

Use natural anchor text:

- HealthSync
- HealthSync Apple Health app sync
- Apple Health app sync for private APIs
- HealthKit-to-API iOS app
- self-hosted Apple Health sync

Avoid repeating one exact-match anchor everywhere.

## Implemented On-Site Link Assets

These repo-side changes make the site easier to link to and more relevant before outreach:

- Added a dedicated resource page at `/apple-health-app-sync`.
- Updated homepage metadata toward `Apple Health app sync`, `HealthKit`, private backend, and self-hosted health data terms.
- Added structured SoftwareApplication data on the homepage.
- Added TechArticle structured data on the resource page.
- Added `/apple-health-app-sync` to the sitemap.
- Added public GitHub README links to the homepage and resource page.
- Linked from the homepage to the new resource page with natural anchor text.

## Backlink Priority List

### 1. GitHub Repository Link and Topics

Status: implemented on 2026-06-05.

Why it matters: the repo is public at `github.com/megabyte0x/healthykit`; GitHub links are crawlable and topically strong for developer searches. GitHub topic pages for Apple Health and health tracking are also indexed and relevant:

- https://github.com/topics/applehealth
- https://github.com/topics/health-tracking

Actions:

- Keep the README links to the homepage and `/apple-health-app-sync`.
- Repository metadata now points the homepage to `/apple-health-app-sync`.
- Repository topics are now set to `apple-health`, `applehealth`, `healthkit`, `ios`, `swiftui`, `self-hosted`, `health-data`, `health-tracking`, `fastapi`.
- Pin or feature the repo from the user profile if appropriate.

Target URL: `/apple-health-app-sync`

Suggested anchor: `Apple Health app sync guide`

### 2. GitHub Release Announcement

Status: implemented on 2026-06-05.

Why it matters: GitHub Release pages are crawlable, attached to a public repository, and provide a legitimate project announcement surface rather than an artificial link page.

Live release:

- https://github.com/megabyte0x/healthykit/releases/tag/healthsync-web-seo-launch-2026-06-05

Actions completed:

- Created release `healthsync-web-seo-launch-2026-06-05`.
- Linked naturally to `/apple-health-app-sync`.
- Described the resource page, HealthKit permission model, private backend sync flow, supported data types, and self-hosted use cases.

### 2a. GitHub Profile README

Status: implemented on 2026-06-05.

Why it matters: the public GitHub profile is a crawlable, owner-controlled page with a natural project context. It adds a second GitHub-owned surface that links directly to the Apple Health app sync resource page without depending on a directory maintainer.

Live evidence:

- Raw README includes `HealthSync Apple Health app sync`: https://raw.githubusercontent.com/megabyte0x/megabyte0x/main/README.md
- Profile repository commit: https://github.com/megabyte0x/megabyte0x/commit/bc01e39af4ac03f040b908eca595eafca1541157

Actions completed:

- Added `HealthSync Apple Health app sync` under the GitHub profile `Projects` section.
- Linked to `https://web-megabytes-projects.vercel.app/apple-health-app-sync`.
- Verified the raw README content after push. The rendered `github.com/megabyte0x` profile endpoint may lag due GitHub page caching, so re-check the rendered page before treating it as cache-warmed.

### 2b. GitHub Pages Project Documentation

Status: implemented and live on 2026-06-05.

Why it matters: GitHub Pages gives the project a second crawlable documentation surface on `github.io`, separate from the Vercel app and GitHub repository UI. The page is technical documentation with natural links to the primary Apple Health app sync guide, the source repository, and the launch release.

Live URL:

- https://megabyte0x.github.io/healthykit/apple-health-app-sync/

Actions completed:

- Added static project docs under `docs/` with `.nojekyll` so GitHub Pages can serve the files directly.
- Added an Apple Health app sync documentation page with implementation details and a natural link to `/apple-health-app-sync`.
- Added a docs index page linking to the same primary resource page.
- Enabled GitHub Pages from `main` `/docs`; the project docs and Apple Health sync docs URLs return `200`.

### 2c. GitHub Discussions Announcement

Status: implemented on 2026-06-05.

Why it matters: GitHub Discussions adds a public, project-owned documentation and announcement surface on the repository. It is weaker than accepted third-party directory links, but stronger than an artificial link page because it lives in the project context and can answer the exact HealthKit-to-private-API use case.

Live URL:

- https://github.com/megabyte0x/healthykit/discussions/1

Actions completed:

- Enabled GitHub Discussions for `megabyte0x/healthykit`.
- Created discussion `Apple Health app sync to a private backend` in `Announcements`.
- Linked naturally to the primary Apple Health app sync resource and the GitHub Pages project docs.
- Verified the discussion URL returns public `200` and verified the body through GitHub GraphQL.

### 2d. Personal Portfolio Custom-Domain Link

Status: implemented and live on 2026-06-05.

Why it matters: `www.megabyte.sh` is an existing custom-domain portfolio site with a relevant `/builds` page. A normal project entry there is a cleaner backlink than another synthetic link surface because it is editorially tied to the builder's shipped projects and gives the HealthSync resource a non-GitHub referring domain.

Live URLs:

- https://www.megabyte.sh/builds
- https://www.megabyte.sh/llms.txt

Actions completed:

- Added `HealthSync` to the `/builds` page with a natural `Apple Health app sync guide` link to `https://web-megabytes-projects.vercel.app/apple-health-app-sync`.
- Added HealthSync to `llms.txt` as `HealthSync Apple Health app sync`, pointing to the same primary resource page.
- Built and tested the portfolio site in a temp clone with `yarn build` and `yarn test`.
- Pushed portfolio commit `83105cb update: add HealthSync build` to `megabyte0x/megabyte0x.xyz`.
- Deployed the site to Vercel production deployment `dpl_5td24QJ1hzp63fDZaLK518jCA9sH`, aliased to `https://www.megabyte.sh`.
- Verified with a live fetch that both `https://www.megabyte.sh/builds` and `https://www.megabyte.sh/llms.txt` return `200` and contain the HealthSync target URL.

### 2e. Personal Blog Technical Article

Status: implemented and live on 2026-06-05.

Why it matters: a real article gives the backlink surrounding topical copy for `Apple Health app sync`, `HealthKit`, `private backend API`, and `self-hosted health data`. This is a stronger owned-media signal than another short profile link because it explains the problem the target page solves and links from a crawlable BlogPosting route on the custom domain.

Live URL:

- https://www.megabyte.sh/blogs/apple-health-app-sync-to-private-api

Actions completed:

- Published `Apple Health app sync to a private API` on the `megabyte0x.xyz` blog.
- Linked naturally to `https://web-megabytes-projects.vercel.app/apple-health-app-sync` near the top of the article and again in the resource section.
- Added the article to `https://www.megabyte.sh/llms.txt`.
- Regenerated and tracked `public/sitemap.xml`; `public/feed.xml` is generated but ignored by this repo.
- Updated `scripts/native-blog.test.cjs` so the Hashnode-import coverage check allows additional native posts while still requiring all expected imported slugs.
- Built and tested the portfolio site with `yarn build` and `yarn test`.
- Pushed portfolio commit `b3e3635 update: publish HealthSync sync note` to `megabyte0x/megabyte0x.xyz`.
- Deployed Vercel production deployment `dpl_Gna4J134iA7aLWYc5szGBdXc8fuf`, aliased to `https://www.megabyte.sh`.
- Verified live fetches: the article returns `200` and contains the HealthSync target URL; sitemap and feed contain the article URL; `llms.txt` contains both the article URL and the target backlink.

### 3. Product Hunt

Status: queued; requires logged-in maker account and launch assets.

Why it matters: Product Hunt pages rank for iOS and Apple Health app discovery terms. Current Apple Health/HealthKit products appear there, including 0xCal with the tagline `Apple Health Sync`: https://www.producthunt.com/products/0xcal

Actions:

- Launch only when the TestFlight flow is usable and there are screenshots or a short demo.
- Use categories/tags: `iOS`, `Health & Fitness`, `Developer Tools` if the private API angle is primary.
- Link to `/apple-health-app-sync` as the website.
- Include the GitHub repo as an additional link.

Suggested title: `HealthSync`

Suggested tagline: `Sync selected Apple Health data to your own backend`

### 4. App Store Listing

Status: queued until public App Store/TestFlight listing is ready.

Why it matters: Apple App Store pages rank strongly for app names and feature queries. The current SERP is dominated by App Store pages for competitors.

Actions:

- Use subtitle/keywords around `Apple Health sync`, `HealthKit`, `private API`, and `self-hosted`.
- Link the marketing URL to `/apple-health-app-sync`.
- Avoid brand confusion with the existing App Store `HealthSync` by differentiating with `private API`, `self-hosted`, or a naming update if needed.

### 5. BetaList

Status: blocked by domain prerequisite.

Why it matters: relevant for early-access/beta products and can drive discovery links.

Constraint: BetaList says startups need a working website on their own domain and that they do not accept free hosting subdomains such as `vercel.app`, Netlify, Heroku, or direct app store links: https://betalist.com/support and https://betalist.com/terms/submissions

Actions:

- Set a custom domain before submitting.
- Submit the early-access/TestFlight positioning after the page has screenshots and a clear beta value proposition.

Target URL: custom domain `/apple-health-app-sync`

### 6. SaaSHub

Status: queued; requires product submission and verification.

Why it matters: SaaSHub has a submit/verify flow and software-alternative discovery intent: https://www.saashub.com/submit

Actions:

- Submit HealthSync with categories around health data, iOS, self-hosted, and API tooling.
- Use the resource page as the website URL.
- Answer Q&A after verification to add unique topical content.

### 7. Alternative Directories

Status: queued; fit depends on public availability.

Why it matters: users search for alternatives to mature tools like Health Auto Export, HealthFit, and Health Webhook. AlternativeTo and Alternative.me-style listings can create relevant discovery pages.

Actions:

- Submit only after a public listing or reliable TestFlight access exists.
- Position HealthSync as an alternative for `Health Webhook`, `Health Auto Export`, and `HealthFit` only where accurate.
- Use honest differentiation: private backend sync, selected HealthKit types, queued retry, open-source backend.

Reference:

- AlternativeTo app discovery/about page: https://alternativeto.net/software/alternativeto/about/
- Alternative.me submission flow: https://alternative.me/how-to/submit-software/

### 8. Hacker News Show HN

Status: not ready unless people can try the app without a waitlist bottleneck.

Why it matters: strong developer audience for HealthKit-to-API, self-hosted, and quantified-self workflows.

Constraint: Show HN works best when people can try, inspect, or run the thing. A pure waitlist is weak and likely to be treated as promotion. Current Show HN listings are at https://news.ycombinator.com/show

Actions:

- Use only when there is a usable TestFlight link, a public demo, or a self-hostable backend path that readers can inspect.
- Title: `Show HN: HealthSync - sync Apple Health data to your own API`.
- First comment should explain HealthKit constraints, privacy model, backend contract, and what feedback is needed.

### 9. Reddit and Community Mentions

Status: queued; only use when answering real user problems.

Why it matters: the topic has live discussion in self-hosted, quantified-self, Apple Watch, iOS programming, and wearable-data communities.

Actions:

- Do not drop links into unrelated threads.
- Look for posts asking how to get Apple Health data into a self-hosted database, API, Home Assistant, Grafana, or AI assistant.
- Answer with the technical limitation first, then link the resource page or GitHub repo if it genuinely helps.

Relevant communities to monitor:

- r/selfhosted
- r/QuantifiedSelf
- r/iOSProgramming
- r/AppleWatch
- r/shortcuts
- r/webdev

### 10. Open-Source and Quantified-Self Lists

Status: multiple submissions opened on 2026-06-05.

Why it matters: topical links from curated lists can be more valuable than generic startup directories.

Live outreach:

- Opened PR `Add HealthSync` to `woop/awesome-quantified-self`: https://github.com/woop/awesome-quantified-self/pull/140
- The PR adds HealthSync under `Applications and Platforms` -> `Aggregators & Dashboards`.
- The entry links to the Apple Health app sync resource page with the description `Sync selected Apple Health data to a private backend API (iOS).`
- Opened PR `Add HealthSync project` to Open Source Observer's OSS Directory: https://github.com/opensource-observer/oss-directory/pull/1094
- The OSS Directory PR adds the HealthSync GitHub artifact plus the Apple Health app sync resource page under `websites`.
- Submitted `megabyte0x/healthykit` to GitDB; GitDB accepted and indexed the API record at `https://p.gitdb.net/api/v1/megabyte0x/healthykit`, but the public HTML page currently sends `x-robots-tag: noindex, nofollow`, so treat it as discovery/indexing value rather than an SEO backlink.
- Evaluated `Dieterbe/awesome-health-fitness-oss`; it is active and relevant, but it is explicitly for Free/Open Source projects. HealthSync currently has no detected license file or GitHub license metadata, so do not submit there until the repo license is chosen.
- Evaluated `OpenAltFinder`; the submission form is relevant but protected by Cloudflare Turnstile, so it needs a manual browser submission with a valid captcha token.
- Evaluated the HealthSync GitHub Wiki; repository settings report wiki enabled, but `https://github.com/megabyte0x/healthykit.wiki.git` returns `Repository not found` and rejected an initial wiki-page push. Initialize the wiki from GitHub's web UI before using it as a project-owned documentation backlink.
- Evaluated `paidx.org`; it has a no-account suggestion form for alternatives, but the endpoint was not exposed through the static HTML. Treat it as a manual suggestion candidate only if HealthSync is positioned as a free alternative to a paid Apple Health export/sync app.
- Evaluated pinning `megabyte0x/healthykit` on the GitHub profile. The profile already has six pinned repositories, so do not replace a pin without explicit approval.

Follow-up actions:

- Monitor both PRs and respond to maintainer feedback quickly.
- Decide the HealthSync repository license before submitting to Free/Open Source lists that require license clarity.
- Manually submit to OpenAltFinder if the project is positioned as an alternative to Health Auto Export, Health Webhook, or similar tools.
- Initialize the GitHub Wiki in the web UI if another project-owned GitHub documentation backlink is desired.
- Manually submit to paidx only with honest alternative positioning and license status.
- Pin `megabyte0x/healthykit` on the GitHub profile only after choosing which existing pinned repository to replace.
- Submit to additional relevant Apple Health, HealthKit, self-hosted health, and personal data lists only where HealthSync is a genuine fit.
- Pitch the resource as `HealthKit to private API sync` rather than generic health tracking.

Potential target classes:

- GitHub awesome lists for quantified self, HealthKit, self-hosted health, and personal data.
- Personal Science/Open Humans style resources, if maintainers accept app/tool listings.

## Outreach Copy

Short directory description:

> HealthSync is a privacy-first iOS app that syncs selected Apple Health data from HealthKit to a private backend API. It is built for self-hosted dashboards, quantified-self databases, and users who want HealthKit data outside Apple's Health app without giving a third-party cloud direct access.

Founder/community note:

> I built HealthSync for people who want Apple Health data in their own backend. HealthKit access still has to happen on-device after user permission, so the app reads selected data types locally, queues sync batches, and posts them to a backend URL the user controls. The resource page explains the flow and the repo includes the SwiftUI app plus FastAPI backend.

Suggested link target:

> https://web-megabytes-projects.vercel.app/apple-health-app-sync

## Prerequisites Before Larger Outreach

- Add a custom domain. This is required for BetaList and looks more credible for every directory.
- Add screenshots and a 30-60 second demo GIF/video.
- Confirm the GitHub repo is public, has topics, and has the website URL in repository metadata.
- Add Search Console and submit `sitemap.xml`.
- Use UTM parameters for submissions, but keep canonical URLs clean.
- Decide whether the brand should remain `HealthSync`, because another App Store app already ranks for that exact brand.

## Ranking Monitor

Track weekly until first-page evidence exists:

- `Apple Health app sync`
- `sync Apple Health data to API`
- `HealthKit to API`
- `Apple Health self-hosted sync`
- `Apple Health private backend`
- `HealthSync Apple Health`

Evidence needed before the Codex goal can be completed:

- Current Google SERP screenshot or export showing the target page on page 1 for at least one agreed primary query.
- Search Console impressions/clicks for the target query family.
- Completed or explicitly rejected submissions from the priority list above.
