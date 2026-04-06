import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/admin-api";

function maskKey(key: string | undefined): string {
  if (!key) return "(not set)";
  if (key.length <= 12) return "****";
  return `${key.slice(0, 8)}…${key.slice(-4)}`;
}

export async function GET() {
  if (!(await requireAdmin())) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const sk = process.env.STRIPE_SECRET_KEY;
  const wh = process.env.STRIPE_WEBHOOK_SECRET;
  const site = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

  const mode = sk?.startsWith("sk_live") ? "live" : sk?.startsWith("sk_test") ? "test" : "unknown";

  return NextResponse.json({
    mode,
    stripeSecretKey: maskKey(sk),
    webhookSecretConfigured: Boolean(wh && wh.length > 0),
    webhookEndpointUrl: `${site.replace(/\/$/, "")}/api/stripe/webhook`,
    dashboardUrl:
      mode === "live"
        ? "https://dashboard.stripe.com"
        : "https://dashboard.stripe.com/test",
    env: {
      NEXT_PUBLIC_SITE_URL: site,
      RESEND_CONFIGURED: Boolean(process.env.RESEND_API_KEY),
      DATABASE_CONFIGURED: Boolean(process.env.DATABASE_URL),
    },
    notes: [
      "Webhook must receive checkout.session.completed for purchases to be recorded.",
      "Refunds use the stored PaymentIntent from checkout (retrieved from session if missing).",
    ],
  });
}
