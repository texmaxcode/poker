import { NextResponse } from "next/server";
import { stripe, PRODUCT_PRICE_CENTS, PRODUCT_NAME, CURRENCY } from "@/lib/stripe";

export async function POST() {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

  try {
    const session = await stripe().checkout.sessions.create({
      mode: "payment",
      payment_method_types: ["card"],
      line_items: [
        {
          price_data: {
            currency: CURRENCY,
            unit_amount: PRODUCT_PRICE_CENTS,
            product_data: {
              name: PRODUCT_NAME,
              description:
                "6-max No-Limit Hold'em desktop training app — one-time purchase, all platforms included.",
              images: [`${siteUrl}/screenshots/lobby.png`],
            },
          },
          quantity: 1,
        },
      ],
      success_url: `${siteUrl}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${siteUrl}/pricing`,
      allow_promotion_codes: true,
      billing_address_collection: "auto",
    });

    return NextResponse.json({ url: session.url });
  } catch (err) {
    console.error("[Checkout] Error creating session:", err);
    return NextResponse.json({ error: "Failed to create checkout session" }, { status: 500 });
  }
}
