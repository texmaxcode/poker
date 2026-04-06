import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";
import { stripe as getStripeClient } from "@/lib/stripe";
import { prisma } from "@/lib/prisma";
import { sendDownloadEmail } from "@/lib/email";

export async function POST(req: NextRequest) {
  const body = await req.text();
  const sig = req.headers.get("stripe-signature");
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!sig || !webhookSecret) {
    return NextResponse.json({ error: "Missing signature or webhook secret" }, { status: 400 });
  }

  let event: Stripe.Event;
  try {
    event = getStripeClient().webhooks.constructEvent(body, sig, webhookSecret);
  } catch (err) {
    console.error("[Webhook] Signature verification failed:", err);
    return NextResponse.json({ error: "Invalid signature" }, { status: 400 });
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object as Stripe.Checkout.Session;

    const email = session.customer_details?.email || session.customer_email;
    if (!email) {
      console.error("[Webhook] No email in session:", session.id);
      return NextResponse.json({ error: "No email found" }, { status: 400 });
    }

    // Idempotency — skip if already processed
    const existing = await prisma.purchase.findUnique({
      where: { stripeSessionId: session.id },
    });
    if (existing) {
      return NextResponse.json({ received: true, skipped: true });
    }

    let stripePaymentIntentId: string | null = null;
    const pi = session.payment_intent;
    if (typeof pi === "string") {
      stripePaymentIntentId = pi;
    } else if (pi && typeof pi === "object" && "id" in pi) {
      stripePaymentIntentId = (pi as Stripe.PaymentIntent).id;
    }

    // Store purchase
    const purchase = await prisma.purchase.create({
      data: {
        email,
        stripeSessionId: session.id,
        stripePaymentIntentId,
        amount: session.amount_total ?? 7900,
        currency: session.currency ?? "usd",
      },
    });

    // Send download email
    try {
      await sendDownloadEmail(email);
      await prisma.purchase.update({
        where: { id: purchase.id },
        data: { emailSent: true },
      });
    } catch (emailErr) {
      console.error("[Webhook] Email failed for:", email, emailErr);
      // Don't fail the webhook — email can be retried manually
    }

    console.log(`[Webhook] Purchase recorded for ${email}`);
  }

  return NextResponse.json({ received: true });
}
