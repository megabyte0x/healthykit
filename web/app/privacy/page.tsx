import type { Metadata } from "next";
import Image from "next/image";
import { absoluteUrl } from "@/lib/site";

const contactEmail = "contact@megabyte0x.xyz";
const pageTitle = "Privacy Policy";
const pageDescription =
  "Privacy policy for HealthSync, the iOS app that reads selected Apple Health data on-device and syncs it only to a private destination the user accepts or configures.";

const summaryItems = [
  {
    term: "Health data access",
    detail:
      "HealthSync reads selected Apple Health data only on the iPhone after you grant HealthKit read permission."
  },
  {
    term: "Sync destination",
    detail:
      "Health data leaves the device only after you accept the default private hosted destination or configure your own backend and start a sync."
  },
  {
    term: "Tokens",
    detail:
      "Backend, ingest, and agent tokens are saved in Keychain on the device. Hosted backend records keep token hashes, not raw tokens."
  },
  {
    term: "Website data",
    detail:
      "The website stores access-request and support contact details. It does not read Apple Health data."
  }
];

const collectedItems = [
  "Apple Health samples you choose to sync, such as steps, heart metrics, sleep, workouts, body metrics, energy, and optional nutrition or water data.",
  "A stable local device identifier, selected data-type settings, HealthKit sync anchors, queued upload batches, sync logs, and app settings stored locally by the iOS app.",
  "Backend URL and auth tokens that you enter or receive from hosted HealthSync setup. Tokens are stored in Keychain on the device.",
  "Hosted HealthSync workspace data when you choose hosted storage, including workspace-scoped metrics, workouts, sync batch metadata, token hashes, and private read-only agent endpoint information.",
  "Website access-request or support details such as name, email address, iOS device, and message content when you submit them."
];

const useItems = [
  "To sync selected Apple Health data to the backend destination you choose.",
  "To retry failed uploads, deduplicate HealthKit records, and show sync status inside the app.",
  "To provision hosted HealthSync storage and private read-only agent credentials when you continue with the default hosted mode.",
  "To respond to support requests, manage access requests, and send product communication related to HealthSync."
];

const controlItems = [
  "Revoke HealthSync Health permissions in iPhone Settings or in the Apple Health app.",
  "Stop syncing by removing the backend token, switching storage mode, or uninstalling the app.",
  "Delete local app data by deleting HealthSync from the iPhone.",
  "Rotate self-hosted backend tokens in your own backend, or refresh hosted agent credentials from the app.",
  `Request hosted workspace deletion or support-record deletion by emailing ${contactEmail}.`
];

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: "/privacy"
  },
  openGraph: {
    title: `${pageTitle} | HealthSync`,
    description: pageDescription,
    url: "/privacy",
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

const privacyStructuredData = {
  "@context": "https://schema.org",
  "@type": "WebPage",
  name: "HealthSync Privacy Policy",
  description: pageDescription,
  url: absoluteUrl("/privacy"),
  publisher: {
    "@type": "Organization",
    name: "HealthSync",
    url: absoluteUrl("/"),
    email: contactEmail,
    logo: {
      "@type": "ImageObject",
      url: absoluteUrl("/healthsync-logo.png")
    }
  }
};

export default function PrivacyPage() {
  return (
    <main className="resource-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(privacyStructuredData) }}
      />

      <header className="site-header" aria-label="HealthSync">
        <a className="brand" href="/" aria-label="HealthSync home">
          <Image src="/healthsync-logo.png" alt="" width={42} height={42} priority />
          <span>HealthSync</span>
        </a>
        <nav aria-label="Page">
          <a href="/">Home</a>
          <a href="/apple-health-app-sync">Sync guide</a>
          <a href="/support">Support</a>
        </nav>
      </header>

      <section className="resource-hero policy-hero" aria-labelledby="privacy-title">
        <div className="resource-shell resource-hero-grid">
          <div>
            <p className="resource-kicker">Privacy policy</p>
            <h1 id="privacy-title">HealthSync privacy policy.</h1>
            <p className="resource-lede">
              HealthSync is built around user-controlled Apple Health sync. The app reads selected
              HealthKit data on-device and sends it only to the private destination you accept or configure.
            </p>
            <p className="policy-updated">Last updated: June 5, 2026</p>
          </div>

          <div className="resource-proof" aria-label="Privacy summary">
            <Image src="/healthsync-logo.png" alt="" width={92} height={92} priority />
            <dl>
              <div>
                <dt>Contact</dt>
                <dd>
                  <a href={`mailto:${contactEmail}`}>{contactEmail}</a>
                </dd>
              </div>
              <div>
                <dt>HealthKit</dt>
                <dd>Read only, with user permission</dd>
              </div>
              <div>
                <dt>Website</dt>
                <dd>No Apple Health access</dd>
              </div>
              <div>
                <dt>Telemetry</dt>
                <dd>No third-party app analytics</dd>
              </div>
            </dl>
          </div>
        </div>
      </section>

      <section className="resource-band muted" aria-labelledby="summary-title">
        <div className="resource-shell">
          <p className="resource-kicker">Summary</p>
          <h2 id="summary-title">The important points.</h2>
          <div className="policy-summary-grid">
            {summaryItems.map((item) => (
              <article key={item.term}>
                <h3>{item.term}</h3>
                <p>{item.detail}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="resource-band" aria-labelledby="collect-title">
        <div className="resource-shell resource-list-grid">
          <div>
            <p className="resource-kicker">Information collected</p>
            <h2 id="collect-title">What HealthSync may store or process.</h2>
            <p className="resource-support">
              The exact data depends on your settings, selected HealthKit categories, and whether
              you use your own backend or hosted HealthSync storage.
            </p>
          </div>
          <ul className="resource-list">
            {collectedItems.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </div>
      </section>

      <section className="resource-band muted" aria-labelledby="use-title">
        <div className="resource-shell resource-list-grid">
          <div>
            <p className="resource-kicker">Use of information</p>
            <h2 id="use-title">Why this information is used.</h2>
          </div>
          <ul className="resource-list accent">
            {useItems.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </div>
      </section>

      <section className="resource-band" aria-labelledby="sharing-title">
        <div className="resource-shell resource-columns">
          <div>
            <p className="resource-kicker">Sharing</p>
            <h2 id="sharing-title">No sale of health data.</h2>
          </div>
          <div className="resource-copy">
            <p>
              HealthSync does not sell Apple Health data. The iOS app does not include advertising
              SDKs, third-party health SDKs, or third-party app analytics.
            </p>
            <p>
              If you configure your own backend, synced data is sent to that backend under your
              control. If you choose hosted HealthSync storage, selected data is stored in a
              workspace scoped to your tokens and made available through private token-protected
              endpoints.
            </p>
            <p>
              Website access requests and support messages may be stored in private production
              storage or sent to the configured support workflow so we can respond.
            </p>
          </div>
        </div>
      </section>

      <section className="resource-band muted" aria-labelledby="retention-title">
        <div className="resource-shell resource-columns">
          <div>
            <p className="resource-kicker">Retention and control</p>
            <h2 id="retention-title">You control Health permissions and sync setup.</h2>
          </div>
          <div className="resource-copy">
            <p>
              Local queued upload batches are kept so failed syncs can retry. Successful batches are
              marked uploaded and pruned after 7 days. Failed network or server uploads remain queued
              until they are retried or local app data is deleted.
            </p>
            <ul className="policy-copy-list">
              {controlItems.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      <section className="resource-band" aria-labelledby="limits-title">
        <div className="resource-shell resource-columns">
          <div>
            <p className="resource-kicker">Limits</p>
            <h2 id="limits-title">Not medical advice.</h2>
          </div>
          <div className="resource-copy">
            <p>
              HealthSync is a data sync utility. It is not a medical device, does not provide
              medical diagnosis or treatment advice, and should not be used for emergencies.
            </p>
            <p>
              HealthSync is not intended for children under 13. If you believe a child provided
              personal information, contact us so it can be removed.
            </p>
            <p>
              Questions or deletion requests can be sent to{" "}
              <a href={`mailto:${contactEmail}`}>{contactEmail}</a>.
            </p>
          </div>
        </div>
      </section>

      <section className="resource-cta" aria-labelledby="support-title">
        <div className="resource-shell">
          <h2 id="support-title">Need help with HealthSync?</h2>
          <p>Use the support page for setup help, troubleshooting, and contact details.</p>
          <a className="resource-button" href="/support">Open support</a>
        </div>
      </section>
    </main>
  );
}
