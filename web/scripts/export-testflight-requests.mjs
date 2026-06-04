const siteUrl = process.env.SITE_URL?.trim() || process.env.NEXT_PUBLIC_SITE_URL?.trim() || "http://localhost:3000";
const adminToken = process.env.TESTFLIGHT_ADMIN_TOKEN;

if (!adminToken) {
  console.error("Missing TESTFLIGHT_ADMIN_TOKEN.");
  process.exit(1);
}

const url = new URL("/api/access-requests", siteUrl);
url.searchParams.set("format", process.argv.includes("--jsonl") ? "jsonl" : "json");

const response = await fetch(url, {
  headers: {
    Authorization: `Bearer ${adminToken}`
  }
});

if (!response.ok) {
  console.error(`Request failed with HTTP ${response.status}`);
  console.error(await response.text());
  process.exit(1);
}

process.stdout.write(await response.text());
