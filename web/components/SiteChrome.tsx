import Image from "next/image";
import { APP_STORE_URL, CONTACT_EMAIL, GITHUB_URL } from "@/lib/site";

const navLinks = [
  { href: "/#how-it-works", label: "How it works" },
  { href: "/#features", label: "Features" },
  { href: "/#developers", label: "Developers" },
  { href: "/docs", label: "Docs" },
  { href: "/support", label: "Support" }
];

export function SiteHeader() {
  return (
    <header className="hs-header" aria-label="HealthSync">
      <div className="hs-header-inner">
        <a className="brand" href="/" aria-label="HealthSync home">
          <Image src="/healthsync-logo.png" alt="" width={28} height={28} priority />
          <span>HealthSync</span>
        </a>
        <nav className="hs-nav" aria-label="Primary">
          {navLinks.map((link) => (
            <a key={link.href} href={link.href}>
              {link.label}
            </a>
          ))}
        </nav>
        <div className="hs-header-actions">
          <a className="hs-github" href={GITHUB_URL} aria-label="HealthSync on GitHub">
            <svg aria-hidden="true" viewBox="0 0 24 24">
              <path d="M12 2a10 10 0 0 0-3.16 19.49c.5.09.68-.22.68-.48v-1.7c-2.78.6-3.37-1.34-3.37-1.34-.45-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.61.07-.61 1 .07 1.53 1.03 1.53 1.03.9 1.52 2.34 1.08 2.91.83.09-.65.35-1.08.63-1.33-2.22-.25-4.55-1.11-4.55-4.94 0-1.09.39-1.98 1.03-2.68-.1-.25-.45-1.27.1-2.65 0 0 .84-.27 2.75 1.02a9.56 9.56 0 0 1 5 0c1.91-1.29 2.75-1.02 2.75-1.02.55 1.38.2 2.4.1 2.65.64.7 1.03 1.59 1.03 2.68 0 3.84-2.34 4.69-4.57 4.93.36.31.68.92.68 1.85v2.75c0 .27.18.58.69.48A10 10 0 0 0 12 2Z" />
            </svg>
          </a>
          <a className="hs-nav-cta" href={APP_STORE_URL}>
            Download
          </a>
        </div>
      </div>
    </header>
  );
}

const footerColumns = [
  {
    title: "Product",
    links: [
      { href: "/#how-it-works", label: "How it works" },
      { href: "/#features", label: "Features" },
      { href: "/#data-types", label: "What syncs" },
      { href: APP_STORE_URL, label: "App Store" }
    ]
  },
  {
    title: "Resources",
    links: [
      { href: "/docs", label: "Documentation" },
      { href: "/support", label: "Support" },
      { href: "/apple-health-app-sync", label: "Apple Health sync guide" },
      { href: "/apple-health-sync-alternatives", label: "Alternatives" },
      { href: GITHUB_URL, label: "Source on GitHub" }
    ]
  },
  {
    title: "Company",
    links: [
      { href: "/privacy", label: "Privacy policy" },
      { href: `mailto:${CONTACT_EMAIL}`, label: "Contact" }
    ]
  }
];

export function SiteFooter() {
  return (
    <footer className="hs-footer">
      <div className="hs-footer-inner">
        <div className="hs-footer-brand">
          <a className="brand" href="/" aria-label="HealthSync home">
            <Image src="/healthsync-logo.png" alt="" width={28} height={28} />
            <span>HealthSync</span>
          </a>
          <p>
            Sync selected Apple Health data from your iPhone to an API you control. Read-only
            HealthKit access, no analytics, no third-party SDKs.
          </p>
        </div>
        {footerColumns.map((column) => (
          <div className="hs-footer-col" key={column.title}>
            <h2>{column.title}</h2>
            <ul>
              {column.links.map((link) => (
                <li key={link.label}>
                  <a href={link.href}>{link.label}</a>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <div className="hs-footer-base">
        <span>© 2026 megabyte0x. Licensed under Apache-2.0.</span>
        <span>HealthSync is a data sync utility, not a medical device.</span>
      </div>
    </footer>
  );
}
