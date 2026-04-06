import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireAdmin } from "@/lib/admin-api";
import { stripe } from "@/lib/stripe";

export async function POST(req: Request) {
  if (!(await requireAdmin())) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let purchaseId = "";
  try {
    const body = await req.json();
    purchaseId = typeof body.purchaseId === "string" ? body.purchaseId : "";
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  if (!purchaseId) {
    return NextResponse.json({ error: "purchaseId required" }, { status: 400 });
  }

  const purchase = await prisma.purchase.findUnique({ where: { id: purchaseId } });
  if (!purchase) {
    return NextResponse.json({ error: "Purchase not found" }, { status: 404 });
  }
  if (purchase.refundedAt) {
    return NextResponse.json({ error: "Already refunded", refundId: purchase.stripeRefundId }, { status: 400 });
  }

  let paymentIntentId = purchase.stripePaymentIntentId;
  if (!paymentIntentId) {
    const session = await stripe().checkout.sessions.retrieve(purchase.stripeSessionId, {
      expand: ["payment_intent"],
    });
    const pi = session.payment_intent;
    if (typeof pi === "string") {
      paymentIntentId = pi;
    } else if (pi && typeof pi === "object" && "id" in pi) {
      paymentIntentId = (pi as { id: string }).id;
    }
    if (paymentIntentId) {
      await prisma.purchase.update({
        where: { id: purchase.id },
        data: { stripePaymentIntentId: paymentIntentId },
      });
    }
  }

  if (!paymentIntentId) {
    return NextResponse.json(
      { error: "Could not resolve payment — check Stripe Dashboard for this session" },
      { status: 400 }
    );
  }

  try {
    const refund = await stripe().refunds.create({
      payment_intent: paymentIntentId,
      reason: "requested_by_customer",
    });

    await prisma.purchase.update({
      where: { id: purchase.id },
      data: {
        refundedAt: new Date(),
        stripeRefundId: refund.id,
      },
    });

    return NextResponse.json({
      ok: true,
      refundId: refund.id,
      status: refund.status,
      amount: refund.amount,
    });
  } catch (e) {
    console.error("[admin/refund]", e);
    const msg = e instanceof Error ? e.message : "Refund failed";
    return NextResponse.json({ error: msg }, { status: 400 });
  }
}
