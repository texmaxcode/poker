import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireAdmin } from "@/lib/admin-api";
import { AnalyticsEventType } from "@prisma/client";

function startOfUtcDay(d: Date): Date {
  const x = new Date(d);
  x.setUTCHours(0, 0, 0, 0);
  return x;
}

export async function GET() {
  if (!(await requireAdmin())) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);

  const [
    totals,
    clickGroups,
    pathGroups,
    dailyRaw,
    recentSample,
    purchasesSummary,
  ] = await Promise.all([
    prisma.analyticsEvent.groupBy({
      by: ["type"],
      where: { createdAt: { gte: thirtyDaysAgo } },
      _count: { _all: true },
    }),
    prisma.analyticsEvent.groupBy({
      by: ["name"],
      where: { type: AnalyticsEventType.CLICK, createdAt: { gte: thirtyDaysAgo } },
      _count: { _all: true },
    }),
    prisma.analyticsEvent.groupBy({
      by: ["path"],
      where: { type: AnalyticsEventType.PAGE_VIEW, createdAt: { gte: thirtyDaysAgo } },
      _count: { _all: true },
    }),
    prisma.analyticsEvent.findMany({
      where: {
        type: AnalyticsEventType.PAGE_VIEW,
        createdAt: { gte: fourteenDaysAgo },
      },
      select: { createdAt: true },
    }),
    prisma.analyticsEvent.findMany({
      where: { createdAt: { gte: thirtyDaysAgo } },
      orderBy: { createdAt: "desc" },
      take: 100,
      select: {
        id: true,
        type: true,
        name: true,
        path: true,
        referrer: true,
        ip: true,
        createdAt: true,
      },
    }),
    prisma.purchase.aggregate({
      _count: { _all: true },
      _sum: { amount: true },
      where: { refundedAt: null },
    }),
  ]);

  const pageViews = totals.find((t) => t.type === AnalyticsEventType.PAGE_VIEW)?._count._all ?? 0;
  const clicks = totals.find((t) => t.type === AnalyticsEventType.CLICK)?._count._all ?? 0;

  const topClicks = clickGroups
    .map((g) => ({ name: g.name, count: g._count._all }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 30);

  const topPaths = pathGroups
    .map((g) => ({ path: g.path, count: g._count._all }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 20);

  const byDay = new Map<string, number>();
  for (const row of dailyRaw) {
    const key = startOfUtcDay(row.createdAt).toISOString().slice(0, 10);
    byDay.set(key, (byDay.get(key) ?? 0) + 1);
  }
  const dailyPageViews = [...byDay.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([day, count]) => ({ day, count }));

  return NextResponse.json({
    periodDays: 30,
    totals: { pageViews, clicks, allEvents: pageViews + clicks },
    topClicks,
    topPaths,
    dailyPageViews,
    purchases: {
      count: purchasesSummary._count._all,
      revenueCents: purchasesSummary._sum.amount ?? 0,
    },
    recentSample,
  });
}
