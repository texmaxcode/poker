import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { AnalyticsEventType } from "@prisma/client";

const ALLOWED_TYPES: AnalyticsEventType[] = [AnalyticsEventType.PAGE_VIEW, AnalyticsEventType.CLICK];

function getClientIp(req: NextRequest): string | null {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    return forwarded.split(",")[0]?.trim() || null;
  }
  return req.headers.get("x-real-ip");
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const type = body.type as string;
    const name = typeof body.name === "string" ? body.name.slice(0, 200) : "";
    const path = typeof body.path === "string" ? body.path.slice(0, 500) : "/";
    const referrer = typeof body.referrer === "string" ? body.referrer.slice(0, 2000) : null;
    const metadata = body.metadata && typeof body.metadata === "object" ? body.metadata : undefined;

    if (!name || !ALLOWED_TYPES.includes(type as AnalyticsEventType)) {
      return NextResponse.json({ error: "Invalid payload" }, { status: 400 });
    }

    const ua = req.headers.get("user-agent")?.slice(0, 500) || null;
    const ip = getClientIp(req);

    await prisma.analyticsEvent.create({
      data: {
        type: type as AnalyticsEventType,
        name,
        path,
        referrer,
        userAgent: ua,
        ip,
        metadata: metadata ?? undefined,
      },
    });

    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error("[analytics/track]", e);
    return NextResponse.json({ error: "Failed to record" }, { status: 500 });
  }
}
