export const SITE_URL = (
  process.env.NEXT_PUBLIC_SITE_URL?.trim() || "https://healthysync.megabyte.sh"
).replace(/\/+$/, "");

export const SITE_NAME = "HealthSync";
export const APP_STORE_URL = "https://apps.apple.com/in/app/healthysync/id6776575569";
export const ORGANIZATION_ID = `${SITE_URL}/#organization`;
export const WEBSITE_ID = `${SITE_URL}/#website`;

export function absoluteUrl(path = "/") {
  if (path === "/") {
    return SITE_URL;
  }

  return `${SITE_URL}${path.startsWith("/") ? path : `/${path}`}`;
}
