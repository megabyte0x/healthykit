import type { Metadata } from "next";
import Image from "next/image";
import { absoluteUrl } from "@/lib/site";

const pageTitle = "Apple Health Sync Alternatives for Private APIs";
const pageDescription =
  "Compare HealthSync with common Apple Health sync and export options when you need HealthKit data in a private API or self-hosted backend.";

const comparisonRows = [
  {
    option: "HealthSync",
    bestFor: "Sending selected Apple Health data from iPhone to a backend URL you control.",
    privateBackend: "Built in",
    appleHealth: "Native HealthKit reads",
    notes: "Best fit for developers, quantified-self workflows, and private API ingestion."
  },
  {
    option: "Health Auto Export",
    bestFor: "Exporting Apple Health data into files, spreadsheets, automations, or supported integrations.",
    privateBackend: "Integration-dependent",
    appleHealth: "Native app export flow",
    notes: "A strong export tool, but not the same as a small self-hosted ingest backend."
  },
  {
    option: "Health Sync",
    bestFor: "Moving fitness data between popular consumer health and activity services.",
    privateBackend: "No",
    appleHealth: "Consumer sync focus",
    notes: "Useful for cross-service syncing, but the ranking result is a different app and brand."
  },
  {
    option: "HealthKit XML export scripts",
    bestFor: "One-off analysis from the Apple Health export ZIP.",
    privateBackend: "No live sync",
    appleHealth: "Export ZIP parsing",
    notes: "Good for historical analysis, not a recurring iPhone-to-API sync path."
  }
];

const selectionSignals = [
  "You want to own the backend URL and auth token.",
  "You need predictable JSON batches for FastAPI, Postgres, Supabase, or another private service.",
  "You want selected HealthKit types instead of a broad bulk export.",
  "You need retry and backfill behavior for mobile network failures.",
  "You want Apple Health access to stay on-device until the app uploads to your API."
];

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: "/apple-health-sync-alternatives"
  },
  openGraph: {
    title: pageTitle,
    description: pageDescription,
    url: "/apple-health-sync-alternatives",
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

const comparisonStructuredData = {
  "@context": "https://schema.org",
  "@type": "TechArticle",
  headline: pageTitle,
  description: pageDescription,
  url: absoluteUrl("/apple-health-sync-alternatives"),
  image: absoluteUrl("/healthsync-logo.png"),
  about: [
    "Apple Health sync alternatives",
    "HealthKit data export",
    "private health API",
    "self-hosted Apple Health sync"
  ],
  mainEntity: {
    "@type": "ItemList",
    itemListElement: comparisonRows.map((row, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: row.option,
      description: row.bestFor
    }))
  },
  publisher: {
    "@type": "Organization",
    name: "HealthSync",
    logo: {
      "@type": "ImageObject",
      url: absoluteUrl("/healthsync-logo.png")
    }
  }
};

export default function AppleHealthSyncAlternativesPage() {
  return (
    <main className="resource-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(comparisonStructuredData) }}
      />

      <header className="site-header" aria-label="HealthSync">
        <a className="brand" href="/" aria-label="HealthSync home">
          <Image src="/healthsync-logo.png" alt="" width={42} height={42} priority />
          <span>HealthSync</span>
        </a>
        <nav aria-label="Page">
          <a href="/apple-health-app-sync">Sync guide</a>
          <a href="/privacy">Privacy</a>
          <a href="/support">Support</a>
          <a href="#comparison">Compare</a>
          <a href="#private-api">Private API fit</a>
        </nav>
      </header>

      <section className="resource-hero" aria-labelledby="alternatives-title">
        <div className="resource-shell resource-hero-grid">
          <div>
            <p className="resource-kicker">Apple Health sync alternatives</p>
            <h1 id="alternatives-title">Compare Apple Health sync options for private APIs.</h1>
            <p className="resource-lede">
              HealthSync is built for a narrow use case: reading selected Apple Health data through
              HealthKit on iPhone and sending it to a backend endpoint you operate.
            </p>
            <div className="resource-actions">
              <a className="resource-button" href="/apple-health-app-sync">
                Read the HealthSync guide
              </a>
              <a className="resource-text-link" href="https://github.com/megabyte0x/healthykit">
                View source on GitHub
              </a>
            </div>
          </div>

          <div className="resource-proof" aria-label="HealthSync positioning">
            <Image src="/healthsync-logo.png" alt="" width={92} height={92} priority />
            <dl>
              <div>
                <dt>Focus</dt>
                <dd>Apple Health to private API</dd>
              </div>
              <div>
                <dt>Platform</dt>
                <dd>Native iOS app using HealthKit</dd>
              </div>
              <div>
                <dt>Backend</dt>
                <dd>FastAPI-compatible ingest endpoint</dd>
              </div>
              <div>
                <dt>Best for</dt>
                <dd>Self-hosted and quantified-self workflows</dd>
              </div>
            </dl>
          </div>
        </div>
      </section>

      <section className="resource-band muted" id="comparison" aria-labelledby="comparison-title">
        <div className="resource-shell">
          <p className="resource-kicker">Comparison</p>
          <h2 id="comparison-title">Not every Apple Health export tool solves private API sync.</h2>
          <div className="comparison-table" role="table" aria-label="Apple Health sync alternatives">
            <div className="comparison-row comparison-head" role="row">
              <div role="columnheader">Option</div>
              <div role="columnheader">Best for</div>
              <div role="columnheader">Private backend</div>
              <div role="columnheader">Apple Health access</div>
              <div role="columnheader">Notes</div>
            </div>
            {comparisonRows.map((row) => (
              <div className="comparison-row" role="row" key={row.option}>
                <div role="cell" data-label="Option">
                  <strong>{row.option}</strong>
                </div>
                <div role="cell" data-label="Best for">{row.bestFor}</div>
                <div role="cell" data-label="Private backend">{row.privateBackend}</div>
                <div role="cell" data-label="Apple Health access">{row.appleHealth}</div>
                <div role="cell" data-label="Notes">{row.notes}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="resource-band" id="private-api" aria-labelledby="fit-title">
        <div className="resource-shell resource-list-grid">
          <div>
            <p className="resource-kicker">Private API fit</p>
            <h2 id="fit-title">Choose HealthSync when backend ownership is the point.</h2>
            <p className="resource-support">
              If you only need a file export, a spreadsheet, or cross-service fitness sync, another
              tool may be better. HealthSync is for users who want HealthKit data to land in their
              own API with predictable payloads and local control.
            </p>
          </div>
          <ul className="resource-list">
            {selectionSignals.map((signal) => (
              <li key={signal}>{signal}</li>
            ))}
          </ul>
        </div>
      </section>

      <section className="resource-band muted" aria-labelledby="search-title">
        <div className="resource-shell resource-columns">
          <div>
            <p className="resource-kicker">Search context</p>
            <h2 id="search-title">The HealthSync name is shared by other apps.</h2>
          </div>
          <div className="resource-copy">
            <p>
              Search results for Apple Health sync include a different App Store app named
              HealthSync and the appyhapps Health Sync product. This page uses the more precise
              phrase <strong>Apple Health to private API</strong> so users can distinguish this
              project from consumer fitness-sync products.
            </p>
            <p>
              For implementation details, supported data types, and the HealthKit permission model,
              use the primary{" "}
              <a href="/apple-health-app-sync">HealthSync Apple Health app sync guide</a>.
            </p>
          </div>
        </div>
      </section>

      <section className="resource-cta" aria-labelledby="cta-title">
        <div className="resource-shell">
          <h2 id="cta-title">Build a private Apple Health sync path.</h2>
          <p>
            Start with the HealthSync guide, then connect the iOS app to a backend endpoint you
            control.
          </p>
          <a className="resource-button" href="/apple-health-app-sync">Open the sync guide</a>
        </div>
      </section>
    </main>
  );
}
