import type { Metadata } from "next";
import Image from "next/image";
import { absoluteUrl } from "@/lib/site";

const contactEmail = "contact@megabyte0x.xyz";
const pageTitle = "Support";
const pageDescription =
  "Support for HealthSync, including contact details, setup help, and troubleshooting for Apple Health sync to a private backend or hosted storage.";

const quickStartItems = [
  "Open HealthSync and connect Apple Health.",
  "Grant read permission for the health categories you want to sync.",
  "Choose storage mode: your own backend or hosted HealthSync storage.",
  "Configure the backend URL and token, then test the connection.",
  "Run Sync last 24 hours or Backfill date range."
];

const troubleshootingItems = [
  {
    title: "Apple Health permissions are not ready",
    body:
      "Open the Apple Health permission prompt again from HealthSync, or review permissions in iPhone Settings. HealthSync cannot read categories you have not granted."
  },
  {
    title: "Backend connection fails",
    body:
      "Confirm the URL is reachable from the iPhone, uses HTTPS in production, and matches the token saved in HealthSync. For same-Wi-Fi local testing, allow iOS Local Network access if prompted."
  },
  {
    title: "No samples are found",
    body:
      "Check that the selected data types contain Apple Health samples in the chosen date range. Simulators are useful for UI testing but do not represent real Apple Health data availability."
  },
  {
    title: "Uploads keep retrying",
    body:
      "Failed uploads stay queued locally for the next HealthKit update, scheduled catch-up, app activation, or manual sync. Open Sync Logs and confirm the backend is healthy."
  },
  {
    title: "Hosted storage or agent credentials need refresh",
    body:
      "Use the hosted storage controls in Settings to refresh the read-only agent token or reset hosted storage when the saved token is no longer valid."
  }
];

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: "/support"
  },
  openGraph: {
    title: `${pageTitle} | HealthSync`,
    description: pageDescription,
    url: "/support",
    siteName: "HealthSync",
    type: "website",
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

const supportStructuredData = {
  "@context": "https://schema.org",
  "@type": "ContactPage",
  name: "HealthSync Support",
  description: pageDescription,
  url: absoluteUrl("/support"),
  mainEntity: {
    "@type": "Organization",
    name: "HealthSync",
    url: absoluteUrl("/"),
    email: contactEmail,
    contactPoint: {
      "@type": "ContactPoint",
      email: contactEmail,
      contactType: "customer support",
      availableLanguage: "en"
    }
  }
};

export default function SupportPage() {
  return (
    <main className="resource-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(supportStructuredData) }}
      />

      <header className="site-header" aria-label="HealthSync">
        <a className="brand" href="/" aria-label="HealthSync home">
          <Image src="/healthsync-logo.png" alt="" width={42} height={42} priority />
          <span>HealthSync</span>
        </a>
        <nav aria-label="Page">
          <a href="/">Home</a>
          <a href="/apple-health-app-sync">Sync guide</a>
          <a href="/privacy">Privacy</a>
        </nav>
      </header>

      <section className="resource-hero" aria-labelledby="support-title">
        <div className="resource-shell resource-hero-grid">
          <div>
            <p className="resource-kicker">Support</p>
            <h1 id="support-title">HealthSync support.</h1>
            <p className="resource-lede">
              Get help with Apple Health permissions, backend setup, hosted storage, manual sync,
              backfill, and private agent credentials.
            </p>
            <div className="resource-actions">
              <a className="resource-button" href={`mailto:${contactEmail}`}>Email support</a>
              <a className="resource-text-link" href="/privacy">Read the privacy policy</a>
            </div>
          </div>

          <div className="resource-proof" aria-label="Support contact">
            <Image src="/healthsync-logo.png" alt="" width={92} height={92} priority />
            <dl>
              <div>
                <dt>Email</dt>
                <dd>
                  <a href={`mailto:${contactEmail}`}>{contactEmail}</a>
                </dd>
              </div>
              <div>
                <dt>Scope</dt>
                <dd>iOS app setup and sync issues</dd>
              </div>
              <div>
                <dt>Platform</dt>
                <dd>iPhone with Apple Health</dd>
              </div>
              <div>
                <dt>Privacy</dt>
                <dd>No Apple Health data by email unless you choose to share it</dd>
              </div>
            </dl>
          </div>
        </div>
      </section>

      <section className="resource-band muted" aria-labelledby="quick-start-title">
        <div className="resource-shell resource-list-grid">
          <div>
            <p className="resource-kicker">Quick start</p>
            <h2 id="quick-start-title">Start with the working sync path.</h2>
            <p className="resource-support">
              HealthSync syncs selected Apple Health data after HealthKit permission is granted and
              a destination is configured.
            </p>
          </div>
          <ol className="resource-list ordered">
            {quickStartItems.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ol>
        </div>
      </section>

      <section className="resource-band" aria-labelledby="troubleshooting-title">
        <div className="resource-shell">
          <p className="resource-kicker">Troubleshooting</p>
          <h2 id="troubleshooting-title">Common fixes.</h2>
          <div className="support-issue-list">
            {troubleshootingItems.map((item) => (
              <article key={item.title}>
                <h3>{item.title}</h3>
                <p>{item.body}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="resource-band muted" aria-labelledby="contact-title">
        <div className="resource-shell resource-columns">
          <div>
            <p className="resource-kicker">Contact</p>
            <h2 id="contact-title">Send support requests by email.</h2>
          </div>
          <div className="resource-copy">
            <p>
              Email <a href={`mailto:${contactEmail}`}>{contactEmail}</a> with the iPhone model,
              iOS version, app version, storage mode, and the sync log message you see.
            </p>
            <p>
              Do not send raw Apple Health exports, backend tokens, ingest tokens, or agent tokens.
              If a token may have been exposed, rotate or refresh it before continuing.
            </p>
            <p>
              HealthSync is a data sync utility, not a medical device. It does not provide medical
              diagnosis, treatment advice, or emergency support.
            </p>
          </div>
        </div>
      </section>

      <section className="resource-cta" aria-labelledby="guide-title">
        <div className="resource-shell">
          <h2 id="guide-title">Review the Apple Health sync guide.</h2>
          <p>
            The guide explains how HealthSync reads HealthKit data on-device and uploads selected
            JSON batches to a backend you configure.
          </p>
          <a className="resource-button" href="/apple-health-app-sync">Open sync guide</a>
        </div>
      </section>
    </main>
  );
}
