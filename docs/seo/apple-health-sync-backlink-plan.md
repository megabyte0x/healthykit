# HealthSync Apple Health App Sync Backlink Plan

Date: 2026-06-05

Target site: https://healthsync.megabyte.sh

Primary link target: https://healthsync.megabyte.sh/apple-health-app-sync

Primary query family:

- Apple Health app sync
- sync Apple Health data
- HealthKit to API
- Apple Health to private backend
- self-hosted Apple Health sync

## Current Baseline

The live site returns `200` with `index, follow`, but the existing homepage metadata was thin: `HealthSync TestFlight Access` and `Request access to the HealthSync TestFlight app.` Search results for exact/current HealthSync wording showed App Store and competitor pages, not the HealthSync site.

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
- Repository metadata now points the homepage to `https://healthsync.megabyte.sh/apple-health-app-sync`.
- Repository topics are now set to `apple-health`, `applehealth`, `healthkit`, `ios`, `swiftui`, `self-hosted`, `health-data`, `health-tracking`, `fastapi`, `apple-health-sync`, `healthkit-api`, `apple-healthkit`, `health-api`, `personal-health-data`, and `ios-health`.
- Added exact-query topic coverage on 2026-06-05. The topic pages for `apple-health-sync`, `healthkit-api`, `apple-healthkit`, and `personal-health-data` return `200`, and the repo homepage metadata still points to the primary Apple Health app sync resource page.
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
- Linked naturally to `https://healthsync.megabyte.sh/apple-health-app-sync`.
- Described the resource page, HealthKit permission model, private backend sync flow, supported data types, and self-hosted use cases.
- Updated the release notes on 2026-06-05 so the public backlink uses the canonical custom-domain target.

### 2a. GitHub Profile README

Status: implemented on 2026-06-05.

Why it matters: the public GitHub profile is a crawlable, owner-controlled page with a natural project context. It adds a second GitHub-owned surface that links directly to the Apple Health app sync resource page without depending on a directory maintainer.

Live evidence:

- Raw README includes `HealthSync Apple Health app sync`: https://raw.githubusercontent.com/megabyte0x/megabyte0x/main/README.md
- Profile repository custom-domain update commit: https://github.com/megabyte0x/megabyte0x/commit/5ed4e20

Actions completed:

- Added `HealthSync Apple Health app sync` under the GitHub profile `Projects` section.
- Linked to `https://healthsync.megabyte.sh/apple-health-app-sync`.
- Verified the README content through the GitHub Contents API after push. The rendered `github.com/megabyte0x` profile endpoint may lag due GitHub page caching, so re-check the rendered page before treating it as cache-warmed.

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

- Added `HealthSync` to the `/builds` page with a natural `Apple Health app sync guide` link to `https://healthsync.megabyte.sh/apple-health-app-sync`.
- Added HealthSync to `llms.txt` as `HealthSync Apple Health app sync`, pointing to the same primary resource page.
- Built and tested the portfolio site in a temp clone with `yarn build` and `yarn test`.
- Pushed portfolio commit `83105cb update: add HealthSync build` to `megabyte0x/megabyte0x.xyz`.
- Deployed the site to Vercel production deployment `dpl_5td24QJ1hzp63fDZaLK518jCA9sH`, aliased to `https://www.megabyte.sh`.
- Verified with a live fetch that both `https://www.megabyte.sh/builds` and `https://www.megabyte.sh/llms.txt` return `200` and contain the HealthSync target URL.
- Consolidated the portfolio links to the custom-domain target in commit `4d59ab7 update: use HealthSync custom domain`.
- Deployed Vercel production deployment `dpl_ECWrsSa3zHVvfXcyMYHdPHQQ2XmQ`, aliased to `https://www.megabyte.sh`.
- Verified live `/builds`, the Apple Health sync blog article, and `/llms.txt` contain `https://healthsync.megabyte.sh/apple-health-app-sync` and do not contain the old Vercel target.

### 2e. Personal Blog Technical Article

Status: implemented and live on 2026-06-05.

Why it matters: a real article gives the backlink surrounding topical copy for `Apple Health app sync`, `HealthKit`, `private backend API`, and `self-hosted health data`. This is a stronger owned-media signal than another short profile link because it explains the problem the target page solves and links from a crawlable BlogPosting route on the custom domain.

Live URL:

- https://www.megabyte.sh/blogs/apple-health-app-sync-to-private-api

Actions completed:

- Published `Apple Health app sync to a private API` on the `megabyte0x.xyz` blog.
- Linked naturally to `https://healthsync.megabyte.sh/apple-health-app-sync` near the top of the article and again in the resource section.
- Added the article to `https://www.megabyte.sh/llms.txt`.
- Regenerated and tracked `public/sitemap.xml`; `public/feed.xml` is generated but ignored by this repo.
- Updated `scripts/native-blog.test.cjs` so the Hashnode-import coverage check allows additional native posts while still requiring all expected imported slugs.
- Built and tested the portfolio site with `yarn build` and `yarn test`.
- Pushed portfolio commit `b3e3635 update: publish HealthSync sync note` to `megabyte0x/megabyte0x.xyz`.
- Deployed Vercel production deployment `dpl_Gna4J134iA7aLWYc5szGBdXc8fuf`, aliased to `https://www.megabyte.sh`.
- Verified live fetches: the article returns `200` and contains the HealthSync target URL; sitemap and feed contain the article URL; `llms.txt` contains both the article URL and the target backlink.
- Consolidated the article and `llms.txt` backlinks to the custom-domain HealthSync target in portfolio commit `4d59ab7`, then redeployed `www.megabyte.sh` in production deployment `dpl_ECWrsSa3zHVvfXcyMYHdPHQQ2XmQ`.

### 2f. GitHub Gist Technical Reference

Status: implemented and live on 2026-06-05.

Why it matters: a public Gist gives the project a compact, crawlable technical reference on another GitHub surface. It is useful for outreach where the full product page is too heavy, and it links naturally to the primary Apple Health app sync resource, source repo, GitHub Pages docs, and launch release.

Live URL:

- https://gist.github.com/megabyte0x/5ceb317b2b30eb97ce3cd5c9e8f645e3

Actions completed:

- Created `Apple Health app sync to a private API` as a public GitHub Gist.
- Linked naturally to `https://healthsync.megabyte.sh/apple-health-app-sync`, `https://github.com/megabyte0x/healthykit`, `https://megabyte0x.github.io/healthykit/apple-health-app-sync/`, and the GitHub launch release.
- Updated the Gist content on 2026-06-05 so the product/setup links use the canonical custom-domain target.
- Verified the Gist content through the GitHub API after update.

### 2g. Custom-Domain HealthSync URL

Status: implemented and live on 2026-06-05.

Why it matters: `healthsync.megabyte.sh` gives outreach and directory submissions a project-specific custom-domain URL instead of a `vercel.app` hosting subdomain. That removes a common product-directory blocker and makes the link target more credible for search results and directories.

Live URLs:

- https://healthsync.megabyte.sh/
- https://healthsync.megabyte.sh/apple-health-app-sync
- https://healthsync.megabyte.sh/sitemap.xml

Actions completed:

- Added `healthsync.megabyte.sh` to the linked Vercel project `web`.
- Verified `/`, `/apple-health-app-sync`, and `/sitemap.xml` return `200` with `index, follow`.
- Switched the app default canonical base URL, repository README links, GitHub Pages documentation links, and production `NEXT_PUBLIC_SITE_URL` target to `https://healthsync.megabyte.sh` so the custom domain is the primary SEO surface.
- Deployed production Vercel deployment `dpl_59DSAr8Yt9CR45a7fA29JV6wXuZt`, aliased to `https://healthsync.megabyte.sh`.
- Verified the live `/apple-health-app-sync` page returns `200` with `x-robots-tag: index, follow`, and now emits canonical, Open Graph, Twitter image, and TechArticle schema URLs on `https://healthsync.megabyte.sh`.
- Verified the live sitemap now lists `https://healthsync.megabyte.sh` and `https://healthsync.megabyte.sh/apple-health-app-sync`.
- `vercel domains inspect healthsync.megabyte.sh` still returns a Vercel CLI `403` for subdomain metadata, despite DNS and HTTP serving correctly. Treat the live HTTP evidence as authoritative and re-check the Vercel dashboard later if project-domain metadata needs cleanup.

### 2h. Apple Health Sync Alternatives Page

Status: implemented locally on 2026-06-05; deploy through the normal main-branch Vercel flow.

Why it matters: current search results show competitor and alternative-intent pages for the existing App Store `HealthSync`, appyhapps `Health Sync`, SaaSHub `Health Sync alternatives`, Apple Health alternatives, and tools such as Health Auto Export. A focused comparison page gives HealthSync a crawlable target for `Apple Health sync alternatives`, clarifies the shared-name problem, and internally links back to the primary Apple Health app sync guide.

Actions:

- Added `/apple-health-sync-alternatives` with canonical metadata, TechArticle/ItemList schema, and comparison copy for HealthSync, Health Auto Export, Health Sync, and one-off HealthKit export scripts.
- Linked the alternatives page from `/apple-health-app-sync`.
- Added `/apple-health-sync-alternatives` to the Next.js sitemap.

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

Status: domain prerequisite resolved; submission still requires a logged-in/manual submit flow and launch assets.

Why it matters: relevant for early-access/beta products and can drive discovery links.

Constraint: BetaList says startups need a working website on their own domain and that they do not accept free hosting subdomains such as `vercel.app`, Netlify, Heroku, or direct app store links: https://betalist.com/support and https://betalist.com/terms/submissions

Actions:

- Use `https://healthsync.megabyte.sh/apple-health-app-sync` for submission if BetaList rejects the canonical `vercel.app` URL.
- Submit the early-access/TestFlight positioning after the page has screenshots and a clear beta value proposition.

Target URL: custom domain `/apple-health-app-sync`

### 6. SaaSHub

Status: blocked by release/account quality gates and current fetchability; custom-domain prerequisite is now available.

Why it matters: SaaSHub has a submit/verify flow and software-alternative discovery intent: https://www.saashub.com/submit

Actions:

- Treat `https://www.saashub.com/health-sync-alternatives` as the most relevant future suggestion target because it already ranks for `Health Sync alternatives` and asks users to suggest missing competitors.
- Submit HealthSync with categories around health data, iOS, self-hosted, and API tooling only after the product is sufficiently public for SaaSHub verification.
- Use the custom-domain resource URL if SaaSHub rejects the canonical `vercel.app` URL.
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
- Opened PR `Add HealthSync by @megabyte0x` to `dkhamsing/open-source-ios-apps`: https://github.com/dkhamsing/open-source-ios-apps/pull/2233
- The PR adds HealthSync to the active `Open-Source iOS Apps` directory under `health` and `swiftui`, with the GitHub repo as `source`, the Apple Health app sync resource page as `homepage`, and a real simulator screenshot at `https://raw.githubusercontent.com/megabyte0x/healthykit/main/docs/assets/healthsync-onboarding.png`.
- Captured the screenshot from the iPhone 16 simulator after building and launching the SwiftUI app locally; the screenshot shows the HealthSync onboarding screen with Apple Health access, private destination, controlled sync, and the `Connect Apple Health` call to action.
- Opened PR `Add HealthSync by @megabyte0x` to `Correia-jpv/fucking-open-source-ios-apps`: https://github.com/Correia-jpv/fucking-open-source-ios-apps/pull/2
- The PR adds HealthSync to an active iOS open-source app directory under `health` and `swiftui`, with the GitHub repo as `source`, the Apple Health app sync resource page as `homepage`, and the same public onboarding screenshot. The PR is open, ready for review, and mergeable; GitHub reported no checks on the branch, while local validation passed with `jq empty contents.json` and `ruby .github/osia_validate_categories.rb`.
- Opened PR `Add HealthSync SwiftUI example` to `jogendra/example-ios-apps`: https://github.com/jogendra/example-ios-apps/pull/124
- The PR adds HealthSync to the `iOS Apps that written with SwiftUI` section of a 1.3k-star Swift example app directory. The entry links the GitHub source and includes a direct `Apple Health app sync guide` backlink to the primary resource page. The PR is open, ready for review, and mergeable; GitHub reported no checks on the branch. The upstream repository is useful but has a stale open PR queue, so count the open PR as a crawlable contextual backlink and treat a merge as uncertain upside.
- Opened PR `Add HealthSync` to `onmyway133/awesome-swiftui`: https://github.com/onmyway133/awesome-swiftui/pull/36
- The PR adds HealthSync to the `Open source apps` -> `iOS` section of a 1k-star SwiftUI resource list. The entry links the GitHub source with the description `SwiftUI app that syncs selected Apple Health data from HealthKit to a private backend API.` The source repository homepage and README link onward to the primary Apple Health app sync resource page. The PR is open, ready for review, and mergeable; GitHub reports no checks on the branch.
- Opened PR `Add HealthSync SwiftUI app` to `ygit/swiftui`: https://github.com/ygit/swiftui/pull/36
- The PR adds HealthSync to an active 1.2k-star SwiftUI resource list as a SwiftUI app entry. The entry links the GitHub source and includes a direct contextual backlink to the primary Apple Health app sync resource page with the anchor `syncing Apple Health data to a private backend API`. The PR is open, maintainer-editable, and mergeable; GitHub reports no checks on the branch.
- Opened PR `Add HealthSync app` to `Juanpe/About-SwiftUI`: https://github.com/Juanpe/About-SwiftUI/pull/171
- The PR adds HealthSync to the `Apps` section of a 7k-star SwiftUI resource list. The entry links directly to `https://healthsync.megabyte.sh/apple-health-app-sync` with the description `A SwiftUI iOS app that syncs selected Apple Health data from HealthKit to a private backend API.` The PR is open and mergeable; GitHub reports no comments or reviews.
- Opened PR `Add HealthSync app` to `vlondon/awesome-swiftui`: https://github.com/vlondon/awesome-swiftui/pull/55
- The PR adds HealthSync to the `Apps` section of a 1.9k-star SwiftUI resource list. The entry links directly to `https://healthsync.megabyte.sh/apple-health-app-sync` with the description `Sync selected Apple Health data from HealthKit to a private backend API.` The PR is open and mergeable; GitHub reports no comments or reviews.
- Opened PR `Add HealthSync` to `uhub/awesome-swift`: https://github.com/uhub/awesome-swift/pull/27
- The PR adds HealthSync to an 844-star Swift frameworks, libraries, and software list in the existing source-repository format. The entry links the GitHub source and describes HealthSync as a SwiftUI iOS app for syncing selected Apple Health data from HealthKit to a private backend API. The PR body includes the canonical target `https://healthsync.megabyte.sh/apple-health-app-sync`. The PR is open, mergeable clean, maintainer-editable, and has no comments or reviews.
- Opened PR `Add HealthSync` to `linsa-io/ios-apps`: https://github.com/linsa-io/ios-apps/pull/5
- The PR adds HealthSync to the `Fitness` section of a curated iOS apps list, linking directly to `https://healthsync.megabyte.sh/apple-health-app-sync` with the description `Sync selected Apple Health data from HealthKit to a private backend API.` The PR is open, mergeable clean, maintainer-editable, and has no comments or reviews.
- Opened PR `Add HealthSync` to `chinsyo/awesome-swiftui`: https://github.com/chinsyo/awesome-swiftui/pull/40
- The PR adds HealthSync to the `Samples` section of a 775-star SwiftUI resource list in the existing source-repository format. The entry links the GitHub source and describes HealthSync as a SwiftUI iOS app for syncing selected Apple Health data from HealthKit to a private backend API. The PR body includes the canonical target `https://healthsync.megabyte.sh/apple-health-app-sync`. The PR is open, mergeable clean, maintainer-editable, and has no comments or reviews.
- Opened PR `Add: HealthSync` to `Axorax/awesome-free-apps`: https://github.com/Axorax/awesome-free-apps/pull/167
- The PR adds HealthSync to the mobile `Health and Wellness` section of a 6.4k-star free-app directory. The entry links directly to `https://healthsync.megabyte.sh/apple-health-app-sync` with the description `Sync selected Apple Health data from HealthKit to a private backend API.` The PR follows the repository's `MOBILE.md`-only contribution guide and requested `Add: name` commit-message style; it is open, mergeable clean, maintainer-editable, and has no comments or reviews.
- Opened PR `Add HealthSync scorecard` to `appscorecards/awesome-mobile-apps`: https://github.com/appscorecards/awesome-mobile-apps/pull/1
- The PR adds HealthSync to the `Fitness` section and creates `scorecards/healthsync.md` with a conservative scorecard for the Apple Health-to-private-backend workflow. The scorecard links directly to `https://healthsync.megabyte.sh/apple-health-app-sync` under `Links`. The upstream repository is new and has no star authority yet, but it is active, structured, and editorially relevant; the PR is open, mergeable clean, maintainer-editable, and has no comments or reviews.
- Opened PR `Add HealthSync` to `Tim9Liu9/TimLiu-iOS`: https://github.com/Tim9Liu9/TimLiu-iOS/pull/147
- The PR adds HealthSync to the `Swift.md` complete-app section of an 11.6k-star iOS resource list, linking directly to `https://healthsync.megabyte.sh/apple-health-app-sync` and also linking the source repo. The upstream repository is broad and has a slow review queue, but it explicitly accepts PRs and is topically relevant for Swift iOS app discovery; the PR is open, mergeable clean, maintainer-editable, and has one automatic vacation-reply style comment but no reviews.
- Opened discussion issue `Suggestion: add HealthSync to HealthKit resources` on `eleev/ios-learning-materials`: https://github.com/eleev/ios-learning-materials/issues/91
- The issue follows the repository's contribution guide, which asks contributors to discuss changes before making them. It proposes HealthSync for the dedicated `HealthKit` resource section of a 3k-star iOS learning list and links both the Apple Health app sync resource page and the source repo. Treat it as outreach until the maintainer invites or accepts a PR.
- Opened PR `Add HealthSync` to `Mylittleswift/ios-health-fitness-apps`: https://github.com/Mylittleswift/ios-health-fitness-apps/pull/1
- The PR adds HealthSync to a HealthKit/CareKit/ResearchKit app list under `Open-source apps` -> `Health`, linking the Apple Health app sync resource page and the GitHub repo. The upstream repository is relevant but stale, so count the open PR as a crawlable contextual backlink and treat a merge as upside rather than a near-term certainty.
- Opened PR `Add HealthSync to Health` to `mikeroyal/Self-Hosting-Guide`: https://github.com/mikeroyal/Self-Hosting-Guide/pull/365
- The PR adds HealthSync to the `Health` section of a 20.1k-star self-hosting guide, linking directly to `https://healthsync.megabyte.sh/apple-health-app-sync`. The description is constrained to the real fit: `SwiftUI iOS app with a self-hosted FastAPI backend for syncing selected Apple Health data from HealthKit to a private API.` The PR is open, mergeable clean, maintainer-editable, and has no comments or reviews.
- Submitted `megabyte0x/healthykit` to GitDB; GitDB accepted and indexed the API record at `https://p.gitdb.net/api/v1/megabyte0x/healthykit`, but the public HTML page currently sends `x-robots-tag: noindex, nofollow`, so treat it as discovery/indexing value rather than an SEO backlink.
- Created public GitHub Gist `Apple Health app sync to a private API`: https://gist.github.com/megabyte0x/5ceb317b2b30eb97ce3cd5c9e8f645e3
- The Gist explains the HealthKit-to-private-API sync model and links to the primary Apple Health app sync resource page, GitHub source, GitHub Pages docs, and launch release. Verified the public page returns `200` and the raw content contains the target URL.
- Consolidated open PR branch backlinks to the custom-domain target on 2026-06-05:
- `woop/awesome-quantified-self#140` head `c5292c0`, open and mergeable clean.
- `opensource-observer/oss-directory#1094` head `17a1ed54`, open and mergeable unstable due existing checks.
- `dkhamsing/open-source-ios-apps#2233` head `02728df3`, open and mergeable unstable due existing checks.
- `Correia-jpv/fucking-open-source-ios-apps#2` head `5e8dad38`, open and mergeable clean.
- `jogendra/example-ios-apps#124` head `c18860a`, open and mergeable clean.
- `Mylittleswift/ios-health-fitness-apps#1` head `bd4d611`, open and mergeable clean.
- `ygit/swiftui#36` head `b42ca13`, open and mergeable with upstream branch protection reported as blocked.
- Evaluated `Dieterbe/awesome-health-fitness-oss`; it is active and relevant, but it is explicitly for Free/Open Source projects. HealthSync currently has no detected license file or GitHub license metadata, so do not submit there until the repo license is chosen.
- Evaluated `vsouza/awesome-ios`; it is active and high-authority, but contribution rules require 100+ GitHub stars, more than one contributor, an OSI-approved license, and Swift Package Manager support. HealthSync does not qualify yet, so do not submit until those hard requirements are met.
- Evaluated `openappssh/openapps`; it has a relevant `fitness` category and a self-hosted project comparison format, but guidelines require open-source projects with clear licensing. HealthSync currently lacks license metadata, so do not submit until the license is chosen.
- Evaluated `paytience/FindAPIs`; it is active and has a Health category, but its guidelines require a free public API with documentation and warn against marketing-company API submissions. HealthSync is an iOS app plus self-hosted/private backend flow, not a public API service, so do not submit there unless a public documented hosted API is launched.
- Evaluated `OpenAltFinder`; the submission form is relevant but protected by Cloudflare Turnstile, so it needs a manual browser submission with a valid captcha token.
- Evaluated GitOpen.dev; the homepage returns `200` and publishes `index, follow`, and the site has a `Submit your GitHub repository` flow. The client submission path requires a signed-in GitHub session and posts to `/api/user/projects`, so queue it for manual account-backed submission rather than attempting an unauthenticated request.
- Evaluated the HealthSync GitHub Wiki; repository settings report wiki enabled and the current GitHub token has admin permission, but `https://github.com/megabyte0x/healthykit.wiki.git` still returns `Repository not found` and rejected a refreshed initial wiki-page push. Initialize the wiki from GitHub's web UI before using it as a project-owned documentation backlink.
- Evaluated `paidx.org`; it has a no-account suggestion form for alternatives, but the endpoint was not exposed through the static HTML. Treat it as a manual suggestion candidate only if HealthSync is positioned as a free alternative to a paid Apple Health export/sync app.
- Evaluated pinning `megabyte0x/healthykit` on the GitHub profile. The profile already has six pinned repositories, so do not replace a pin without explicit approval.
- Evaluated `jobbole/awesome-ios-cn`; it has strong historical authority, but it is a Chinese iOS library/resource catalog without a clean complete-app or HealthKit product slot for HealthSync, so do not submit there.
- Evaluated `pluja/awesome-privacy`; it is high-authority and has a relevant Fitness and Health section, but its scope is free/open-source privacy-respecting alternatives. HealthSync currently lacks license metadata, so do not submit there until the license is chosen.
- Evaluated `matteocrippa/awesome-swift`; it is high-authority and active, but its `contents.json` is organized around Swift libraries/resources rather than complete end-user apps. Do not force HealthSync into this list unless the repo grows a reusable Swift package or library surface.
- Evaluated `kakoni/awesome-healthcare`; it is relevant and active, but contribution rules require acknowledged open-source licensing or an explicit `(Commercial Software)` note plus reasonable recognition/adoption and production/GA quality. HealthSync currently has no license metadata and remains TestFlight-stage, so do not submit yet.
- Evaluated OSSEAN; it is crawlable and relevant for open-source startup discovery, but no trustworthy PR or submit route was exposed in the page or GitHub search, so keep it as research-only until a submission path appears.
- Evaluated FossFinder/OpenSourceHunt, OpenSRC.ME, OSSAlternatives, and LibHunt. FossFinder/OpenSourceHunt did not expose usable submission markup, OpenSRC.ME failed TLS from this machine, OSSAlternatives failed DNS resolution, and LibHunt returned a Cloudflare challenge; treat them as manual or retry-later candidates only.

Follow-up actions:

- Monitor open directory PRs and respond to maintainer feedback quickly.
- Add more public app screenshots if maintainers ask for additional screens or App Store-style image dimensions.
- Use the public GitHub Gist as a compact technical reference in future outreach where a long product page is too heavy.
- Monitor `onmyway133/awesome-swiftui#36` and respond if the maintainer asks for a different description or link target.
- Monitor `ygit/swiftui#36` and respond if the maintainer wants a shorter description or source-only link format.
- Monitor `Juanpe/About-SwiftUI#171` and `vlondon/awesome-swiftui#55`; both are valuable direct app-list backlinks if accepted, but both upstream repositories have older contribution queues.
- Monitor `uhub/awesome-swift#27`; it is a broad Swift/software list, so maintainer acceptance may depend on whether they want end-user SwiftUI apps alongside frameworks and tools.
- Monitor `linsa-io/ios-apps#5`; it is a direct Fitness-category app backlink, but the upstream list has sparse recent history.
- Monitor `chinsyo/awesome-swiftui#40`; it is a relevant SwiftUI sample backlink, but the upstream list mixes old and current sample entries.
- Monitor `Axorax/awesome-free-apps#167`; it is the strongest broad mobile-app directory submission so far by star count, but maintainer review may focus on whether HealthSync is broadly useful enough for a general free-app list.
- Monitor `appscorecards/awesome-mobile-apps#1`; it is not high authority yet, but it provides a structured scorecard backlink if accepted.
- Monitor `Tim9Liu9/TimLiu-iOS#147`; it is a high-authority broad iOS resource backlink if accepted, but the upstream review queue appears slow.
- Monitor `eleev/ios-learning-materials#91`; if the maintainer agrees it fits, submit a one-line PR to `Lists/HealthKit.md`.
- Monitor `mikeroyal/Self-Hosting-Guide#365`; it is the highest-authority self-hosting-health backlink currently open, and maintainer review may focus on whether an iOS app plus self-hosted backend fits the guide's server-oriented scope.
- Decide the HealthSync repository license before submitting to Free/Open Source lists that require license clarity.
- Submit `megabyte0x/healthykit` to GitOpen.dev after signing in with GitHub; it is an indexable directory but requires an authenticated session.
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

> https://healthsync.megabyte.sh/apple-health-app-sync

## Prerequisites Before Larger Outreach

- Use the live custom domain `https://healthsync.megabyte.sh` for new directories and outreach; keep canonical URLs clean so signals consolidate to `/apple-health-app-sync`.
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
