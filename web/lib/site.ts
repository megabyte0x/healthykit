export const SITE_URL = (
  process.env.NEXT_PUBLIC_SITE_URL?.trim() || "https://healthsync.megabyte.sh"
).replace(/\/+$/, "");

export function absoluteUrl(path = "/") {
  if (path === "/") {
    return SITE_URL;
  }

  return `${SITE_URL}${path.startsWith("/") ? path : `/${path}`}`;
}
