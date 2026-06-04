const siteUrl = process.env.SITE_URL?.trim() || process.env.NEXT_PUBLIC_SITE_URL?.trim() || "http://localhost:3000";
const url = new URL("/api/health", siteUrl);
const response = await fetch(url);
const body = await response.text();

if (!response.ok) {
  console.error(`Health check failed with HTTP ${response.status}`);
  console.error(body);
  process.exit(1);
}

const parsed = JSON.parse(body);
if (!parsed.ok) {
  console.error("Health check returned ok=false.");
  console.error(body);
  process.exit(1);
}

console.log(JSON.stringify(parsed, null, 2));
