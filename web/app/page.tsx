import Image from "next/image";
import { AccessRequestForm } from "@/components/access-request-form";
import { absoluteUrl } from "@/lib/site";

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
    title: "Access and support only",
    body: "We collect your name, email, and iOS device only to manage access requests and HealthSync communication.",
    icon: "person"
  },
  {
    title: "No health data here",
    body: "This website never reads, stores, or has access to your Apple Health data.",
    icon: "lock"
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
    body: "Upload selected metrics and workouts to a backend URL you configure, with queued retries for network failures.",
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
    title: "Check your email",
    body: "We will review the request and send install instructions when beta access is available.",
    icon: "mail"
  },
  {
    title: "Install via TestFlight",
    body: "Open the invite on your iOS device and install HealthSync through Apple's TestFlight app.",
    icon: "testflight"
  },
  {
    title: "Share feedback",
    body: "Try the sync flow, then tell us what should be clearer before launch.",
    icon: "message"
  }
];

const homeStructuredData = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "HealthSync",
  applicationCategory: "HealthApplication",
  operatingSystem: "iOS",
  url: absoluteUrl("/"),
  description:
    "Privacy-first iOS app for syncing selected Apple Health data from HealthKit to a private backend API.",
  image: absoluteUrl("/healthsync-logo.png"),
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "USD",
    availability: "https://schema.org/PreOrder"
  },
  featureList: [
    "Apple Health app sync through HealthKit",
    "Private REST backend uploads",
    "Selected HealthKit data type toggles",
    "Queued retry for failed sync batches",
    "No website access to Apple Health data"
  ],
  sameAs: ["https://github.com/megabyte0x/healthykit"]
};

const faqItems = [
  {
    question: "Do I need TestFlight installed?",
    answer: "Yes. Approved testers install HealthSync through Apple TestFlight on the iOS device they submit."
  },
  {
    question: "Will this website read my Apple Health data?",
    answer: "No. This website only collects TestFlight access details. Apple Health permissions are handled inside the iOS app."
  },
  {
    question: "When will I get access?",
    answer: "Requests are reviewed manually. If approved, install instructions are sent to the email address you provide."
  },
  {
    question: "Can I choose what HealthSync syncs?",
    answer: "Yes. HealthSync lets you choose the health data types and sync timing from inside the iOS app."
  }
];

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

  if (name === "person") {
    return (
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <circle cx="12" cy="8" r="3.4" />
        <path d="M5.5 20a6.5 6.5 0 0 1 13 0" />
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

  if (name === "mail") {
    return (
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <rect width="16" height="12" x="4" y="6" rx="2" />
        <path d="m5 7.5 7 5.4 7-5.4" />
      </svg>
    );
  }

  if (name === "testflight") {
    return (
      <svg aria-hidden="true" viewBox="0 0 24 24">
        <rect width="14" height="14" x="5" y="5" rx="4" />
        <path d="m12 8.2-3.4 7" />
        <path d="m12 8.2 3.4 7" />
        <path d="M8.6 15.2h6.8" />
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
          <a className="nav-action" href="#request-access">Request access</a>
        </nav>
      </header>

      <section className="hero-section" id="top" aria-labelledby="hero-title">
        <div className="hero-grid" id="product">
          <div className="hero-copy">
            <h1 id="hero-title">Apple Health app sync for your own backend</h1>
            <p className="lede">
              Request TestFlight access to HealthSync, the iOS app that syncs selected
              HealthKit data to a private API endpoint on your terms.
            </p>
            <div className="hero-links" aria-label="Primary actions">
              <a className="text-action" href="#request-access">Join the TestFlight list</a>
              <a className="text-action secondary" href="/apple-health-app-sync">
                Read the Apple Health sync guide
              </a>
            </div>
            <div className="hero-form" id="request-access" aria-labelledby="request-form-title">
              <div className="form-heading">
                <h2 id="request-form-title">Join the TestFlight list</h2>
                <p>We review requests manually and send install instructions by email.</p>
              </div>
              <AccessRequestForm />
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
            <h2 id="privacy-title">Privacy, built into the request.</h2>
            <p>
              We collect only what is needed to manage HealthSync access and support: your name,
              email, and iOS device. We never read or access your Apple Health data from this
              website.
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
              <Icon name="testflight" />
              <span>What happens next</span>
            </div>
            <h2 id="next-title">What happens next</h2>
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
            <p>Everything you need to know about requests, privacy, and the beta.</p>
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
