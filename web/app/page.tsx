import Image from "next/image";
import type { ReactNode } from "react";
import { Icon } from "@/components/Icon";
import { SiteFooter, SiteHeader } from "@/components/SiteChrome";
import { absoluteUrl, APP_STORE_URL, GITHUB_URL, ORGANIZATION_ID } from "@/lib/site";

const steps = [
  {
    screen: "/screens/02-health-access-prompt.webp",
    alt: "Apple Health permission sheet asking to allow HealthSync to read selected data",
    title: "Grant read-only access",
    body: "Choose exactly which Apple Health types HealthSync may read. It never writes to Health, and you can change access any time."
  },
  {
    screen: "/screens/01-onboarding.webp",
    alt: "HealthSync onboarding screen with hosted storage and controlled sync options",
    title: "Pick a destination",
    body: "Tap Continue for a private hosted workspace, or enter your own backend URL and token in Settings."
  },
  {
    screen: "/screens/06-historical-sync.webp",
    alt: "HealthSync historical sync screen with a start and end date",
    title: "Sync and backfill",
    body: "New samples, edits, and deletions upload in the background. Backfill any date range when you need history."
  }
];

const features = [
  {
    icon: "sync",
    title: "Background sync",
    body: "HealthKit change delivery, hourly or daily catch-up, and a sync every time you open the app."
  },
  {
    icon: "calendar",
    title: "Historical backfill",
    body: "Import any date range from Apple Health, or re-sync the last 24 hours with one tap."
  },
  {
    icon: "layers",
    title: "Retry-safe queue",
    body: "Failed batches stay queued on the device. Stable record IDs make every retry duplicate-free."
  },
  {
    icon: "check",
    title: "Deletions included",
    body: "When a sample is removed from Apple Health, the deletion syncs too, so your copy stays accurate."
  },
  {
    icon: "server",
    title: "Hosted or self-hosted",
    body: "Start with a private hosted workspace, or run the open-source FastAPI and Postgres backend."
  },
  {
    icon: "sparkle",
    title: "Ready for AI agents",
    body: "Hosted workspaces include a read-only agent endpoint with daily summaries for LLM tools."
  }
];

const dataCategories = [
  { name: "Activity", examples: "Steps, distance, active energy, exercise minutes" },
  { name: "Heart", examples: "Heart rate, resting HR, HRV, VO2 max, blood pressure" },
  { name: "Sleep & Mindfulness", examples: "Sleep stages, mindful minutes" },
  { name: "Body", examples: "Weight, body fat, BMI, lean mass, wrist temperature" },
  { name: "Workouts", examples: "Type, duration, energy, distance, heart rate, effort" },
  { name: "Nutrition", examples: "Calories, macros, water, vitamins, minerals" },
  { name: "Respiratory", examples: "Respiratory rate, blood oxygen, lung function" },
  { name: "Mobility", examples: "Walking steadiness, gait, stair speed" },
  { name: "Hearing & Environment", examples: "Audio exposure, daylight, UV" },
  { name: "Clinical", examples: "Blood glucose, insulin, alcohol" },
  { name: "Reproductive Health", examples: "Cycle tracking and related records" },
  { name: "Symptoms & Events", examples: "Symptoms, hygiene, and other events" }
];

const privacyPoints = [
  {
    icon: "shield",
    title: "Read-only HealthKit",
    body: "HealthSync never writes to Apple Health and only reads the types you enable."
  },
  {
    icon: "lock",
    title: "Tokens in the Keychain",
    body: "Backend and agent tokens live in the iOS Keychain and are never written to logs."
  },
  {
    icon: "check",
    title: "No analytics in the app",
    body: "No tracking, telemetry, ad SDKs, or third-party health SDKs. Nothing phones home."
  },
  {
    icon: "code",
    title: "Open source",
    body: "The app and backend are Apache-2.0 licensed, so you can audit exactly what is sent."
  }
];

const faqItems = [
  {
    question: "Where can I download HealthSync?",
    answer: "HealthSync is available from the App Store for iPhone."
  },
  {
    question: "Is HealthSync free?",
    answer: "Yes. HealthSync is free to download from the App Store, and the source code is open under Apache-2.0."
  },
  {
    question: "Will this website read my Apple Health data?",
    answer:
      "No. Apple Health permissions are handled inside the iOS app, and this website never reads or stores your Apple Health data."
  },
  {
    question: "Can I choose what HealthSync syncs?",
    answer:
      "Yes. HealthSync lets you choose the health data types and sync timing from inside the iOS app."
  },
  {
    question: "Do I need my own server?",
    answer:
      "No. By default HealthSync creates a private hosted workspace for you. You can switch to your own backend at any time in Settings."
  },
  {
    question: "How often does HealthSync sync in the background?",
    answer:
      "You can choose hourly, daily, or manual. iOS decides exactly when background work runs, so scheduled syncs are best-effort; manual sync and backfill always run immediately."
  }
];

const samplePayload = `POST /api/apple-health/sync
Authorization: Bearer ••••••••

{
  "schema_version": 2,
  "device_id": "3F2A…",
  "export_id": "b1c4…",
  "timezone": "Europe/Berlin",
  "metrics": [
    {
      "id": "healthkit:9E1D…",
      "type": "step_count",
      "value": 1243,
      "unit": "count",
      "start_at": "2026-10-16T08:00:00Z",
      "end_at": "2026-10-16T09:00:00Z"
    }
  ],
  "workouts": [ … ],
  "deletions": [ … ]
}`;

const homeStructuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      "@id": absoluteUrl("/#software-application"),
      name: "HealthSync",
      applicationCategory: "HealthApplication",
      applicationSubCategory: "Health data synchronization",
      operatingSystem: "iOS",
      url: absoluteUrl("/"),
      description:
        "Privacy-first iOS app for syncing selected Apple Health data from HealthKit to a private backend API.",
      image: absoluteUrl("/healthsync-logo.png"),
      author: {
        "@id": ORGANIZATION_ID
      },
      offers: {
        "@type": "Offer",
        price: "0",
        priceCurrency: "USD",
        availability: "https://schema.org/InStock",
        url: APP_STORE_URL
      },
      featureList: [
        "Apple Health app sync through HealthKit",
        "Private REST backend uploads",
        "Selected HealthKit data type toggles",
        "Automatic HealthKit change delivery and scheduled catch-up",
        "Queued retry for failed sync batches",
        "Backfill of historical Apple Health data",
        "Read-only AI agent endpoint for hosted workspaces",
        "No website access to Apple Health data"
      ],
      sameAs: [APP_STORE_URL, GITHUB_URL]
    },
    {
      "@type": "FAQPage",
      "@id": absoluteUrl("/#faq"),
      mainEntity: faqItems.map((item) => ({
        "@type": "Question",
        name: item.question,
        acceptedAnswer: {
          "@type": "Answer",
          text: item.answer
        }
      }))
    }
  ]
};

// Colors JSON keys, strings, and numbers in the sample request.
function highlight(source: string) {
  const parts: ReactNode[] = [];
  const token = /("[^"]*")(\s*:)?|\b\d+\b/g;
  let last = 0;
  for (const match of source.matchAll(token)) {
    const index = match.index ?? 0;
    parts.push(source.slice(last, index));
    const kind = match[1] ? (match[2] ? "key" : "str") : "num";
    parts.push(
      <span className={`hp-tok-${kind}`} key={index}>
        {match[1] ?? match[0]}
      </span>
    );
    if (match[2]) {
      parts.push(match[2]);
    }
    last = index + match[0].length;
  }
  parts.push(source.slice(last));
  return parts;
}

function AppStoreButton({ variant = "dark" }: { variant?: "dark" | "light" }) {
  return (
    <a className={`hp-store ${variant}`} href={APP_STORE_URL}>
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="M16.4 12.6c0-2.4 2-3.6 2.1-3.7-1.1-1.7-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.8-1.6 0-3.1 1-4 2.4-1.7 3-.4 7.4 1.2 9.8.8 1.2 1.8 2.5 3 2.4 1.2 0 1.7-.8 3.1-.8 1.5 0 1.9.8 3.2.8 1.3 0 2.2-1.2 3-2.4.9-1.4 1.3-2.7 1.3-2.8 0 0-2.5-1-2.5-3.9ZM14 5.4c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1.1.1 2.1-.6 2.8-1.4Z" />
      </svg>
      Download on the App Store
    </a>
  );
}

function Device({ src, alt, priority = false }: { src: string; alt: string; priority?: boolean }) {
  return (
    <div className="hp-device">
      <Image src={src} alt={alt} width={640} height={1387} priority={priority} />
    </div>
  );
}

export default function Home() {
  return (
    <main className="hp">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(homeStructuredData) }}
      />
      <SiteHeader />

      <section className="hp-hero" aria-labelledby="hero-title">
        <div className="lp-shell hp-hero-grid">
          <div className="hp-hero-copy">
            <a className="hp-announce" href={GITHUB_URL}>
              <span className="hp-dot" aria-hidden="true" />
              Open source under Apache-2.0
              <Icon name="arrow" />
            </a>
            <h1 id="hero-title">
              Your Apple Health data, <span>synced to an API you own.</span>
            </h1>
            <p className="hp-lede">
              HealthSync runs on your iPhone, reads only the HealthKit data you choose, and keeps
              it in sync with your own backend or a private hosted workspace. Ready for
              dashboards, databases, and AI agents.
            </p>
            <div className="hp-actions">
              <AppStoreButton />
              <a className="hp-button-secondary" href="/docs">
                Read the docs
              </a>
            </div>
            <ul className="hp-meta" aria-label="Highlights">
              <li>Free on iPhone</li>
              <li>Read-only HealthKit</li>
              <li>No analytics</li>
            </ul>
          </div>

          <div className="hp-hero-visual">
            <div className="hp-hero-back">
              <Device
                src="/screens/05-activity-types.webp"
                alt="HealthSync choosing Apple Health activity types to sync"
              />
            </div>
            <div className="hp-hero-front">
              <Device
                src="/screens/04-settings.webp"
                alt="HealthSync settings with a custom backend, 189 data types selected, and a saved token"
                priority
              />
            </div>
            <div className="hp-hero-log" aria-hidden="true">
              <span className="hp-status-ok">200</span>
              <code>POST /api/apple-health/sync</code>
              <span className="hp-hero-log-meta">142 metrics · 1 workout</span>
            </div>
          </div>
        </div>
      </section>

      <section className="hp-section" id="how-it-works" aria-labelledby="how-title">
        <div className="lp-shell">
          <header className="hp-head">
            <div>
              <p className="hp-eyebrow">How it works</p>
              <h2 id="how-title">From your iPhone to your database in three steps.</h2>
            </div>
            <p>
              Apple doesn&apos;t offer a cloud API for Health data. HealthSync is the bridge: it
              runs where the data lives and delivers it to an endpoint you control.
            </p>
          </header>
          <ol className="hp-steps">
            {steps.map((step, index) => (
              <li key={step.title}>
                <div className="hp-step-shot">
                  <Image src={step.screen} alt={step.alt} width={640} height={1387} />
                </div>
                <span className="hp-step-index">0{index + 1}</span>
                <h3>{step.title}</h3>
                <p>{step.body}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="hp-section hp-tint" id="features" aria-labelledby="features-title">
        <div className="lp-shell">
          <header className="hp-head">
            <div>
              <p className="hp-eyebrow">Features</p>
              <h2 id="features-title">Set it up once. It keeps your data current.</h2>
            </div>
            <p>
              HealthSync handles permissions, background delivery, retries, and deletions, so the
              copy in your database stays accurate without babysitting.
            </p>
          </header>
          <div className="hp-features">
            {features.map((feature) => (
              <article key={feature.title}>
                <Icon name={feature.icon} />
                <h3>{feature.title}</h3>
                <p>{feature.body}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="hp-section" id="data-types" aria-labelledby="data-title">
        <div className="lp-shell hp-split">
          <div className="hp-split-copy">
            <p className="hp-eyebrow">What syncs</p>
            <h2 id="data-title">180+ Apple Health types. You choose which.</h2>
            <p>
              Toggle whole categories or individual types in the app. HealthSync only asks for
              read permission on what you enable.
            </p>
            <a className="hp-link" href="/support#data-types">
              See the export format
              <Icon name="arrow" />
            </a>
          </div>
          <dl className="hp-data">
            {dataCategories.map((category) => (
              <div key={category.name}>
                <dt>{category.name}</dt>
                <dd>{category.examples}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>

      <section className="hp-section hp-dark" id="developers" aria-labelledby="dev-title">
        <div className="lp-shell hp-split">
          <div className="hp-split-copy">
            <p className="hp-eyebrow">For developers</p>
            <h2 id="dev-title">One documented JSON contract.</h2>
            <p>
              Every batch is a single authenticated POST with metrics, workouts, and deletions.
              Record IDs are stable, so your backend can upsert safely on every retry.
            </p>
            <ul className="hp-checks">
              <li>
                <Icon name="check" /> Bearer-token auth with per-device headers
              </li>
              <li>
                <Icon name="check" /> Deterministic <code>healthkit:&#123;uuid&#125;</code> record
                IDs
              </li>
              <li>
                <Icon name="check" /> Open-source FastAPI and Postgres backend
              </li>
              <li>
                <Icon name="check" /> Read-only agent endpoint with daily summaries
              </li>
            </ul>
            <div className="hp-actions">
              <a className="hp-button-light" href="/support#api">
                API reference
              </a>
              <a className="hp-link light" href={GITHUB_URL}>
                View on GitHub
                <Icon name="arrow" />
              </a>
            </div>
          </div>
          <figure className="hp-code" aria-label="Example sync request">
            <figcaption>
              <span>sync-request.http</span>
              <span className="hp-status-ok">200 OK</span>
            </figcaption>
            <pre>
              <code>{highlight(samplePayload)}</code>
            </pre>
          </figure>
        </div>
      </section>

      <section className="hp-section" id="privacy" aria-labelledby="privacy-title">
        <div className="lp-shell">
          <header className="hp-head">
            <div>
              <p className="hp-eyebrow">Privacy</p>
              <h2 id="privacy-title">Private by design, not by promise.</h2>
            </div>
            <p>
              Your health data stays on your iPhone until you sync it, and then it goes only where
              you point it. This website never reads or accesses it.{" "}
              <a className="hp-inline" href="/privacy">
                Read the privacy policy
              </a>
              .
            </p>
          </header>
          <div className="hp-privacy">
            {privacyPoints.map((point) => (
              <article key={point.title}>
                <Icon name={point.icon} />
                <h3>{point.title}</h3>
                <p>{point.body}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="hp-section hp-tint" id="faq" aria-labelledby="faq-title">
        <div className="lp-shell hp-split">
          <div className="hp-split-copy">
            <p className="hp-eyebrow">FAQ</p>
            <h2 id="faq-title">Questions, answered.</h2>
            <p>
              Can&apos;t find what you need? Browse the{" "}
              <a className="hp-inline" href="/docs">
                documentation
              </a>{" "}
              or visit{" "}
              <a className="hp-inline" href="/support">
                Support
              </a>
              .
            </p>
          </div>
          <div className="faq-list">
            {faqItems.map((item) => (
              <details key={item.question}>
                <summary>{item.question}</summary>
                <p>{item.answer}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      <section className="hp-cta-wrap" aria-labelledby="final-title">
        <div className="lp-shell">
          <div className="hp-cta">
            <Image src="/healthsync-logo.png" alt="" width={56} height={56} />
            <h2 id="final-title">Own your Apple Health data.</h2>
            <p>Free on the App Store. Syncing in under a minute.</p>
            <div className="hp-actions center">
              <AppStoreButton variant="light" />
              <a className="hp-button-secondary dark" href="/docs/getting-started">
                Getting started guide
              </a>
            </div>
          </div>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
