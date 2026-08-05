import { absoluteUrl, APP_STORE_URL } from "@/lib/site";

const content = `# HealthSync

> HealthSync is a free iPhone app that syncs selected Apple Health data from HealthKit to a backend URL the user controls.

HealthSync is a data sync utility, not a medical device. It does not provide medical advice, diagnosis, or treatment.

## Primary pages

- [Apple Health app sync guide](${absoluteUrl("/apple-health-app-sync")}): How HealthSync reads selected HealthKit data on-device and uploads queued JSON batches to a private API.
- [Apple Health sync alternatives](${absoluteUrl("/apple-health-sync-alternatives")}): A sourced comparison of private-API, webhook, and export options.
- [Privacy policy](${absoluteUrl("/privacy")}): What HealthSync may process and how users control Health permissions.
- [Support](${absoluteUrl("/support")}): Setup and troubleshooting guidance for HealthKit permissions and backend sync.
- [App Store listing](${APP_STORE_URL}): Download HealthSync for iPhone.
- [Source repository](https://github.com/megabyte0x/healthykit): Open source code and implementation context.

## Facts

- Apple Health permissions are requested only inside the iOS app.
- Users choose which supported HealthKit data types to sync.
- The website does not read or store Apple Health data.
- The configured backend URL and token determine where selected data is sent.

Last reviewed: 2026-08-05
`;

export function GET() {
  return new Response(content, {
    headers: {
      "Cache-Control": "public, max-age=0, must-revalidate",
      "Content-Type": "text/plain; charset=utf-8"
    }
  });
}
