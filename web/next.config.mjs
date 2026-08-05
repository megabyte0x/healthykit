import { fileURLToPath } from "node:url";

const projectRoot = fileURLToPath(new URL(".", import.meta.url));
const isVercelBuild = projectRoot.startsWith("/vercel/");
const isDevelopment = process.env.NODE_ENV === "development";
const scriptSource = [
  "'self'",
  "'unsafe-inline'",
  ...(isDevelopment ? ["'unsafe-eval'"] : [])
].join(" ");

/** @type {import('next').NextConfig} */
const nextConfig = {
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          {
            key: "Content-Security-Policy",
            value: [
              "default-src 'self'",
              "base-uri 'self'",
              "form-action 'self'",
              "frame-ancestors 'none'",
              "img-src 'self' data: blob:",
              `script-src ${scriptSource}`,
              "style-src 'self' 'unsafe-inline'",
              "connect-src 'self'",
              "font-src 'self' data:",
              "object-src 'none'",
              "upgrade-insecure-requests"
            ].join("; ")
          },
          {
            key: "Referrer-Policy",
            value: "strict-origin-when-cross-origin"
          },
          {
            key: "X-Content-Type-Options",
            value: "nosniff"
          },
          {
            key: "X-Frame-Options",
            value: "DENY"
          },
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=(), payment=()"
          },
          {
            key: "X-Robots-Tag",
            value: "index, follow"
          }
        ]
      }
    ];
  },
  ...(isVercelBuild ? {} : { turbopack: { root: projectRoot } })
};

export default nextConfig;
