import { NextResponse } from "next/server";

export function GET() {
  return NextResponse.json(
    {
      ok: true,
      service: "healthsync-website",
      time: new Date().toISOString()
    },
    {
      status: 200,
      headers: {
        "Cache-Control": "no-store"
      }
    }
  );
}
