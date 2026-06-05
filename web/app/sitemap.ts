import type { MetadataRoute } from "next";
import { absoluteUrl } from "@/lib/site";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: absoluteUrl("/"),
      lastModified: new Date(),
      changeFrequency: "monthly",
      priority: 1
    },
    {
      url: absoluteUrl("/apple-health-app-sync"),
      lastModified: new Date(),
      changeFrequency: "monthly",
      priority: 0.9
    },
    {
      url: absoluteUrl("/apple-health-sync-alternatives"),
      lastModified: new Date(),
      changeFrequency: "monthly",
      priority: 0.72
    }
  ];
}
