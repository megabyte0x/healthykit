import type { Metadata } from "next";
import { absoluteUrl, SITE_URL } from "@/lib/site";
import "./globals.css";

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
      "Request TestFlight access for the iOS app that syncs selected Apple Health data to your own backend.",
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
      <body>{children}</body>
    </html>
  );
}
