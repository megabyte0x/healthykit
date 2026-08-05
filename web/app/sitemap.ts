import type { MetadataRoute } from "next";
import { absoluteUrl } from "@/lib/site";

export default function sitemap(): MetadataRoute.Sitemap {
  // Omit lastmod unless a route has a verifiable content-update timestamp. A
  // request-time value incorrectly tells crawlers that every page changed on every build.
  return ["/", "/apple-health-app-sync", "/apple-health-sync-alternatives", "/privacy", "/support"].map(
    (path) => ({ url: absoluteUrl(path) })
  );
}
