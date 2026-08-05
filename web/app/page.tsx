import Image from "next/image";
import { absoluteUrl, APP_STORE_URL, ORGANIZATION_ID } from "@/lib/site";

const previewRows = [
  {
    title: "Ready to sync",
    detail: "Selected data only",
    icon: "check",
    tone: "ready"
  },
  {
    title: "Steps",
    detail: "Activity",
    icon: "steps",
    tone: "green"
  },
  {
    title: "Heart rate",
    detail: "Heart",
    icon: "heart",
    tone: "red"
  },
  {
    title: "Sleep",
    detail: "Sleep",
    icon: "sleep",
    tone: "violet"
  }
];

const privacyDetails = [
  {
    title: "No website health data",
    body: "This website never reads, stores, or has access to your Apple Health data.",
    icon: "lock"
  },
  {
    title: "Control stays with you",
    body: "HealthSync asks for HealthKit permission only inside the iPhone app, for the data types you choose.",
    icon: "shield"
  },
  {
    title: "Clear privacy policy",
    body: "The full App Store privacy policy explains app storage, hosted storage, and deletion requests.",
    icon: "shield"
  }
];

const syncDetails = [
  {
    title: "HealthKit on iPhone",
    body: "HealthSync reads Apple Health data only after the user grants HealthKit permission inside the iOS app.",
    icon: "shield"
  },
  {
    title: "Private API endpoint",
    body: "Automatically upload selected changes to your configured backend, with scheduled catch-up and queued retries for network failures.",
    icon: "lock"
  },
  {
    title: "Selected data only",
    body: "Steps, heart metrics, sleep, workouts, body metrics, energy, and optional nutrition types can be toggled.",
    icon: "check"
  }
];

const nextSteps = [
  {
    title: "Download HealthSync",
    body: "Open the App Store on your iPhone and install HealthSync for free.",
    icon: "download"
  },
  {
    title: "Choose your setup",
    body: "Use the default hosted destination or connect your own private backend.",
    icon: "lock"
  },
  {
    title: "Select and sync",
    body: "Choose the Apple Health data you want to share, then let HealthSync keep it up to date.",
    icon: "check"
  }
];

const faqItems = [
  {
    question: "Where can I download HealthSync?",
    answer: "HealthSync is available from the App Store for iPhone."
  },
  {
    question: "Will this website read my Apple Health data?",
    answer: "No. Apple Health permissions are handled inside the iOS app, and this website never reads or stores your Apple Health data."
  },
  {
    question: "Is HealthSync free?",
    answer: "Yes. HealthSync is free to download from the App Store."
  },
  {
    question: "Can I choose what HealthSync syncs?",
    answer: "Yes. HealthSync lets you choose the health data types and sync timing from inside the iOS app."
  }
];

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
        "No website access to Apple Health data"
      ],
      sameAs: [APP_STORE_URL, "https://github.com/megabyte0x/healthykit"]
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

function Icon({ name }: { name: string }) {
  if (name === "check") {
    return (
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="m6.8 12.4 3.2 3.2 7.2-7.2" />
      </svg>
    );
  }

  if (name === "steps") {
    return (
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="M9.5 5.4a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" />
        <path d="m8.8 7.4-2.1 4.2 3.6 1.8-1.7 5.2" />
        <path d="m11.2 8.2 2.2 2.4h3" />
        <path d="m12.4 14.2 3.2 4" />
      </svg>
    );
  }

  if (name === "heart") {
    return (
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="M20.4 7.8c0 4.8-8.4 9.6-8.4 9.6S3.6 12.6 3.6 7.8A4.1 4.1 0 0 1 10.8 5l1.2 1.3L13.2 5a4.1 4.1 0 0 1 7.2 2.8Z" />
      </svg>
    );
  }

  if (name === "sleep") {
    return (
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="M18.4 15.5A7.6 7.6 0 0 1 8.5 5.6 7.9 7.9 0 1 0 18.4 15.5Z" />
      </svg>
    );
  }

  if (name === "lock") {
    return (
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="M7.2 10.2V8a4.8 4.8 0 0 1 9.6 0v2.2" />
        <rect width="13.4" height="10.5" x="5.3" y="10.2" rx="2" />
        <path d="M12 14.2v2.3" />
      </svg>
    );
  }

  if (name === "shield") {
    return (
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="M12 3.4 19 6v5.2c0 4.3-2.8 7.7-7 9.4-4.2-1.7-7-5.1-7-9.4V6l7-2.6Z" />
        <path d="m8.7 12 2.1 2.1 4.5-4.7" />
      </svg>
    );
  }

  if (name === "download") {
    return (
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="M12 3.5v10.2" />
        <path d="m8.1 10.2 3.9 3.9 3.9-3.9" />
        <path d="M5.2 17.5v2.8h13.6v-2.8" />
      </svg>
    );
  }

  if (name === "message") {
    return (
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <path d="M5 6.2h14v9.6H9.2L5 19.2v-13Z" />
        <path d="M8.4 9.8h7.2" />
        <path d="M8.4 12.4h4.6" />
      </svg>
    );
  }

  return (
    <svg aria-hidden="true" viewBox="0 0 24 24">
      <path d="m9 18 6-6-6-6" />
    </svg>
  );
}

function PhonePreview() {
  return (
    <div className="phone-stage" aria-hidden="true">
      <div className="phone">
        <div className="phone-screen">
          <div className="phone-status">
            <span>9:41</span>
            <div>
              <span />
              <span />
              <span />
            </div>
          </div>
          <div className="phone-app-header">
            <Image src="/healthsync-logo.png" alt="" width={66} height={66} priority />
            <div>
              <strong>HealthSync</strong>
              <span>Sync your health data. On your terms.</span>
            </div>
          </div>
          <div className="preview-list">
            {previewRows.map((row) => (
              <div className={`preview-row ${row.tone}`} key={row.title}>
                <div className="row-icon">
                  <Icon name={row.icon} />
                </div>
                <div>
                  <strong>{row.title}</strong>
                  <span>{row.detail}</span>
                </div>
                <div className="row-state">On</div>
              </div>
            ))}
          </div>
          <div className="phone-privacy">
            <Icon name="lock" />
            <span>Your data stays private. You are in control.</span>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function Home() {
  return (
    <main>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(homeStructuredData) }}
      />
      <header className="site-header" aria-label="HealthSync">
        <a className="brand" href="#top" aria-label="HealthSync home">
          <Image src="/healthsync-logo.png" alt="" width={42} height={42} priority />
          <span>HealthSync</span>
        </a>
        <nav aria-label="Page">
          <a href="#product">Product</a>
          <a href="/apple-health-app-sync">Sync guide</a>
          <a href="/privacy">Privacy</a>
          <a href="/support">Support</a>
          <a href="#faq">FAQ</a>
          <a className="nav-action" href={APP_STORE_URL}>View on the App Store</a>
        </nav>
      </header>

      <section className="hero-section" id="top" aria-labelledby="hero-title">
        <div className="hero-grid" id="product">
          <div className="hero-copy">
            <h1 id="hero-title">Apple Health app sync for your own backend</h1>
            <p className="lede">
              HealthSync is the iOS app that syncs selected HealthKit data to a private API
              endpoint on your terms.
            </p>
            <div className="hero-links" aria-label="Primary actions">
              <a className="text-action" href={APP_STORE_URL}>View on the App Store</a>
              <a className="text-action secondary" href="/apple-health-app-sync">
                Read the Apple Health sync guide
              </a>
            </div>
          </div>

          <PhonePreview />
        </div>
      </section>

      <section className="sync-section" aria-labelledby="sync-title">
        <div className="section-shell sync-grid">
          <div className="section-lede">
            <div className="section-label">
              <Icon name="steps" />
              <span>Apple Health sync</span>
            </div>
            <h2 id="sync-title">Built for HealthKit-to-API workflows.</h2>
            <p>
              HealthSync is for people who want Apple Health data available in their own
              systems without giving a third-party cloud direct access to their health history.
            </p>
            <a className="inline-resource-link" href="/apple-health-app-sync">
              Learn how HealthSync syncs Apple Health data
            </a>
          </div>

          <div className="sync-points">
            {syncDetails.map((item) => (
              <article className="sync-point" key={item.title}>
                <div className="large-icon">
                  <Icon name={item.icon} />
                </div>
                <h3>{item.title}</h3>
                <p>{item.body}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="privacy-section" id="privacy" aria-labelledby="privacy-title">
        <div className="section-shell privacy-grid">
          <div className="section-lede">
            <div className="section-label">
              <Icon name="lock" />
              <span>Privacy</span>
            </div>
            <h2 id="privacy-title">Privacy, built into the app.</h2>
            <p>
              Your Apple Health data stays on your iPhone until you choose to sync it from inside
              HealthSync. This website never reads or accesses it.
            </p>
            <div className="privacy-note">
              <Icon name="shield" />
              <span>Your health data stays on your device unless you choose to sync it inside the app.</span>
            </div>
            <a className="inline-resource-link" href="/privacy">Read the full privacy policy</a>
          </div>

          <div className="privacy-points">
            {privacyDetails.map((item) => (
              <article className="privacy-point" key={item.title}>
                <div className="large-icon">
                  <Icon name={item.icon} />
                </div>
                <h3>{item.title}</h3>
                <p>{item.body}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="process-section" aria-labelledby="next-title">
        <div className="section-shell process-grid">
          <div className="section-lede compact">
            <div className="section-label">
              <Icon name="download" />
              <span>Get started</span>
            </div>
            <h2 id="next-title">Get started with HealthSync.</h2>
          </div>

          <div className="steps">
            {nextSteps.map((step, index) => (
              <article className="step" key={step.title}>
                <div className="step-number">{index + 1}</div>
                <div className="step-icon">
                  <Icon name={step.icon} />
                </div>
                <h3>{step.title}</h3>
                <p>{step.body}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="faq-section" id="faq" aria-labelledby="faq-title">
        <div className="section-shell faq-grid">
          <div className="section-lede compact">
            <div className="section-label faq-label">
              <Icon name="message" />
              <span>FAQ</span>
            </div>
            <h2 id="faq-title">Frequently asked questions</h2>
            <p>Everything you need to know about the app, privacy, and Apple Health sync.</p>
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
    </main>
  );
}
