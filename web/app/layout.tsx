import type { Metadata } from "next";
import { Analytics } from "@vercel/analytics/next";
import {
  absoluteUrl,
  APP_STORE_URL,
  ORGANIZATION_ID,
  SITE_NAME,
  SITE_URL,
  WEBSITE_ID
} from "@/lib/site";
import "./globals.css";

const siteStructuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Organization",
      "@id": ORGANIZATION_ID,
      name: SITE_NAME,
      url: SITE_URL,
      logo: {
        "@type": "ImageObject",
        url: absoluteUrl("/healthsync-logo.png")
      },
      sameAs: [APP_STORE_URL, "https://github.com/megabyte0x/healthykit"]
    },
    {
      "@type": "WebSite",
      "@id": WEBSITE_ID,
      name: SITE_NAME,
      url: SITE_URL,
      inLanguage: "en",
      publisher: {
        "@id": ORGANIZATION_ID
      }
    }
  ]
};

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: "HealthSync - Apple Health App Sync for Private APIs",
    template: "%s | HealthSync"
  },
  description:
    "HealthSync is a privacy-first iOS app for syncing selected Apple Health data from HealthKit to your own backend.",
  keywords: [
    "Apple Health app sync",
    "HealthKit sync",
    "Apple Health API",
    "sync Apple Health data",
    "self-hosted health data"
  ],
  alternates: {
    canonical: "/"
  },
  openGraph: {
    title: "HealthSync - Apple Health App Sync for Private APIs",
    description:
      "Privacy-first iOS Apple Health sync for selected HealthKit data and private API endpoints.",
    url: "/",
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
  },
  twitter: {
    card: "summary",
    title: "HealthSync - Apple Health App Sync for Private APIs",
    description:
      "Privacy-first iOS Apple Health sync for selected HealthKit data and private API endpoints.",
    images: [absoluteUrl("/healthsync-logo.png")]
  },
  robots: {
    index: true,
    follow: true
  }
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(siteStructuredData) }}
        />
        {children}
        <Analytics />
      </body>
    </html>
  );
}
