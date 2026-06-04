import { NextResponse } from "next/server";
import { getRequestStorageMode } from "@/lib/access-request-store";

export const runtime = "nodejs";

export function GET() {
  const storage = getRequestStorageMode();
  const ok = storage !== "unconfigured";

  return NextResponse.json(
    {
      ok,
      service: "healthsync-testflight-access",
      storage,
      time: new Date().toISOString()
    },
    {
      status: ok ? 200 : 503,
      headers: {
        "Cache-Control": "no-store"
      }
    }
  );
}
