import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireAdmin } from "@/lib/admin-api";

export async function GET() {
  if (!(await requireAdmin())) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const purchases = await prisma.purchase.findMany({
    orderBy: { createdAt: "desc" },
    take: 200,
    select: {
      id: true,
      email: true,
      stripeSessionId: true,
      stripePaymentIntentId: true,
      amount: true,
      currency: true,
      emailSent: true,
      refundedAt: true,
      stripeRefundId: true,
      createdAt: true,
    },
  });

  return NextResponse.json({ purchases });
}
