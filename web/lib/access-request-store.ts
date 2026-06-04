import { mkdir, appendFile, readFile } from "node:fs/promises";
import path from "node:path";
import { get, list, put } from "@vercel/blob";
import type { AccessRequest } from "@/lib/access-requests";

export type StoredAccessRequest = AccessRequest & {
  id: string;
  createdAt: string;
  userAgent?: string;
};

export type RequestStorageMode =
  | "webhook"
  | "vercel-blob"
  | "local-log"
  | "unconfigured";

const ACCESS_REQUEST_LOG_PATH = path.join(process.cwd(), "data", "testflight-requests.jsonl");
const BLOB_PREFIX = "testflight-requests";

function hasBlobStorage() {
  return Boolean(process.env.BLOB_READ_WRITE_TOKEN || (process.env.VERCEL_OIDC_TOKEN && process.env.BLOB_STORE_ID));
}

export function getRequestStorageMode(): RequestStorageMode {
  if (process.env.TESTFLIGHT_REQUEST_WEBHOOK_URL?.trim()) {
    return "webhook";
  }

  if (hasBlobStorage()) {
    return "vercel-blob";
  }

  if (process.env.VERCEL) {
    return "unconfigured";
  }

  return "local-log";
}

function getBlobPath(request: StoredAccessRequest) {
  const date = request.createdAt.slice(0, 10);
  return `${BLOB_PREFIX}/${date}/${request.createdAt.replace(/[:.]/g, "-")}-${request.id}.json`;
}

async function persistToWebhook(request: StoredAccessRequest, webhookUrl: string) {
  const response = await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(request)
  });

  if (!response.ok) {
    throw new Error(`Webhook delivery failed with status ${response.status}`);
  }
}

async function persistToBlob(request: StoredAccessRequest) {
  await put(getBlobPath(request), JSON.stringify(request, null, 2), {
    access: "private",
    addRandomSuffix: false,
    allowOverwrite: false,
    contentType: "application/json"
  });
}

async function persistToLocalLog(request: StoredAccessRequest) {
  await mkdir(path.dirname(ACCESS_REQUEST_LOG_PATH), { recursive: true });
  await appendFile(ACCESS_REQUEST_LOG_PATH, `${JSON.stringify(request)}\n`, "utf8");
}

export async function persistAccessRequest(request: StoredAccessRequest) {
  const mode = getRequestStorageMode();

  if (mode === "webhook") {
    await persistToWebhook(request, process.env.TESTFLIGHT_REQUEST_WEBHOOK_URL!.trim());
    return mode;
  }

  if (mode === "vercel-blob") {
    await persistToBlob(request);
    return mode;
  }

  if (mode === "local-log") {
    await persistToLocalLog(request);
    return mode;
  }

  throw new Error("Production request storage is not configured.");
}

async function readStream(stream: ReadableStream<Uint8Array>) {
  const response = new Response(stream);
  return response.text();
}

async function readBlobRequests() {
  const requests: StoredAccessRequest[] = [];
  let cursor: string | undefined;

  do {
    const page = await list({
      cursor,
      limit: 1000,
      prefix: `${BLOB_PREFIX}/`
    });

    for (const blob of page.blobs) {
      const result = await get(blob.pathname, { access: "private", useCache: false });
      if (!result || result.statusCode !== 200) {
        continue;
      }
      requests.push(JSON.parse(await readStream(result.stream)) as StoredAccessRequest);
    }

    cursor = page.cursor;
  } while (cursor);

  return requests;
}

async function readLocalRequests() {
  try {
    const contents = await readFile(ACCESS_REQUEST_LOG_PATH, "utf8");
    return contents
      .split("\n")
      .filter(Boolean)
      .map((line) => JSON.parse(line) as StoredAccessRequest);
  } catch (error) {
    if (error && typeof error === "object" && "code" in error && error.code === "ENOENT") {
      return [];
    }
    throw error;
  }
}

export async function listAccessRequests() {
  const mode = getRequestStorageMode();

  if (mode === "vercel-blob") {
    return readBlobRequests();
  }

  if (mode === "local-log") {
    return readLocalRequests();
  }

  throw new Error(`Listing requests is not supported for ${mode} storage.`);
}
