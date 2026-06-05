import type { Metadata } from "next";
import Image from "next/image";
import { absoluteUrl } from "@/lib/site";

const pageTitle = "Apple Health App Sync for Private APIs";
const pageDescription =
  "How HealthSync syncs selected Apple Health data from HealthKit on iPhone to a private backend API without giving this website access to health data.";

const syncedTypes = [
  "Steps and activity energy",
  "Heart rate, resting heart rate, and HRV SDNN",
  "Sleep analysis",
  "Workouts",
  "Body mass and body fat percentage",
  "Optional dietary energy, macros, and water"
];

const useCases = [
  "Self-hosted personal health dashboards",
  "Private quantified-self databases",
  "HealthKit-to-FastAPI or Postgres ingestion",
  "Personal AI agents that need read-only health summaries",
  "Backfill and retry workflows for unreliable mobile networks"
];

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: "/apple-health-app-sync"
  },
  openGraph: {
    title: pageTitle,
    description: pageDescription,
    url: "/apple-health-app-sync",
    siteName: "HealthSync",
    type: "article",
    images: [
      {
        url: absoluteUrl("/healthsync-logo.png"),
        width: 1024,
        height: 1024,
        alt: "HealthSync app icon"
      }
    ]
  }
};

const articleStructuredData = {
  "@context": "https://schema.org",
  "@type": "TechArticle",
  headline: pageTitle,
  description: pageDescription,
  url: absoluteUrl("/apple-health-app-sync"),
  image: absoluteUrl("/healthsync-logo.png"),
  about: ["Apple Health app sync", "HealthKit", "private health data APIs", "self-hosted health data"],
  publisher: {
    "@type": "Organization",
    name: "HealthSync",
    logo: {
      "@type": "ImageObject",
      url: absoluteUrl("/healthsync-logo.png")
    }
  }
};

export default function AppleHealthAppSyncPage() {
  return (
    <main className="resource-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(articleStructuredData) }}
      />

      <header className="site-header" aria-label="HealthSync">
        <a className="brand" href="/" aria-label="HealthSync home">
          <Image src="/healthsync-logo.png" alt="" width={42} height={42} priority />
          <span>HealthSync</span>
        </a>
        <nav aria-label="Page">
          <a href="/">Request access</a>
          <a href="#how-it-works">How it works</a>
          <a href="/privacy">Privacy</a>
          <a href="/support">Support</a>
          <a href="#use-cases">Use cases</a>
          <a href="/apple-health-sync-alternatives">Alternatives</a>
        </nav>
      </header>

      <section className="resource-hero" aria-labelledby="resource-title">
        <div className="resource-shell resource-hero-grid">
          <div>
            <p className="resource-kicker">Apple Health app sync</p>
            <h1 id="resource-title">Sync Apple Health data to your own backend.</h1>
            <p className="resource-lede">
              HealthSync is a native iOS app that reads selected HealthKit data on-device and
              uploads queued JSON batches to a backend API you configure.
            </p>
            <div className="resource-actions">
              <a className="resource-button" href="/#request-access">Request TestFlight access</a>
              <a className="resource-text-link" href="https://github.com/megabyte0x/healthykit">
                View the GitHub repo
              </a>
            </div>
          </div>

          <div className="resource-proof" aria-label="HealthSync sync summary">
            <Image src="/healthsync-logo.png" alt="" width={92} height={92} priority />
            <dl>
              <div>
                <dt>Source</dt>
                <dd>Apple Health through HealthKit</dd>
              </div>
              <div>
                <dt>Destination</dt>
                <dd>Your REST backend</dd>
              </div>
              <div>
                <dt>Access</dt>
                <dd>Read-only health permissions</dd>
              </div>
              <div>
                <dt>Mode</dt>
                <dd>Manual sync, backfill, and queued retry</dd>
              </div>
            </dl>
          </div>
        </div>
      </section>

      <section className="resource-band" id="how-it-works" aria-labelledby="how-title">
        <div className="resource-shell resource-columns">
          <div>
            <p className="resource-kicker">How it works</p>
            <h2 id="how-title">The website never reads your Apple Health data.</h2>
          </div>
          <div className="resource-copy">
            <p>
              Apple Health access runs through HealthKit on the iPhone after the user grants
              permission. The HealthSync website only collects TestFlight access requests; the iOS app
              handles HealthKit authorization, selected data type toggles, local persistence, and sync.
            </p>
            <p>
              Apple describes HealthKit as the central store for health and fitness data on iPhone and
              Apple Watch, with app access controlled by user permission. HealthSync follows that model
              and sends data only to the backend URL and token configured inside the app.
            </p>
            <p>
              Reference:{" "}
              <a href="https://developer.apple.com/documentation/healthkit">
                Apple HealthKit developer documentation
              </a>{" "}
              and{" "}
              <a href="https://www.apple.com/legal/privacy/data/en/health-app/">
                Apple Health app privacy information
              </a>.
            </p>
          </div>
        </div>
      </section>

      <section className="resource-band muted" aria-labelledby="types-title">
        <div className="resource-shell resource-list-grid">
          <div>
            <p className="resource-kicker">Supported data</p>
            <h2 id="types-title">Selected HealthKit types, not a bulk data dump.</h2>
            <p className="resource-support">
              HealthSync is built around explicit toggles and predictable backend payloads, so a
              private API can ingest only the health data types the user chooses.
            </p>
          </div>
          <ul className="resource-list">
            {syncedTypes.map((type) => (
              <li key={type}>{type}</li>
            ))}
          </ul>
        </div>
      </section>

      <section className="resource-band" id="use-cases" aria-labelledby="uses-title">
        <div className="resource-shell resource-list-grid">
          <div>
            <p className="resource-kicker">Use cases</p>
            <h2 id="uses-title">Built for private Apple Health sync workflows.</h2>
            <p className="resource-support">
              The best fit is a user-controlled backend: a local API, hosted FastAPI service,
              Supabase-backed endpoint, or another HTTPS service that you operate.
            </p>
          </div>
          <ul className="resource-list accent">
            {useCases.map((useCase) => (
              <li key={useCase}>{useCase}</li>
            ))}
          </ul>
        </div>
      </section>

      <section className="resource-cta" aria-labelledby="cta-title">
        <div className="resource-shell">
          <h2 id="cta-title">Try HealthSync through TestFlight.</h2>
          <p>
            Request access if you want to test Apple Health app sync with your own private API
            endpoint.
          </p>
          <a className="resource-button" href="/#request-access">Request access</a>
        </div>
      </section>

      <section className="resource-band muted" aria-labelledby="alternatives-title">
        <div className="resource-shell resource-columns">
          <div>
            <p className="resource-kicker">Alternatives</p>
            <h2 id="alternatives-title">Compare Apple Health sync options.</h2>
          </div>
          <div className="resource-copy">
            <p>
              If you are comparing HealthSync with Health Auto Export, Health Sync, or one-off
              HealthKit export scripts, use the comparison page to decide whether you need a private
              API sync workflow or a simpler export tool.
            </p>
            <p>
              Read the{" "}
              <a href="/apple-health-sync-alternatives">
                Apple Health sync alternatives comparison
              </a>
              .
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
