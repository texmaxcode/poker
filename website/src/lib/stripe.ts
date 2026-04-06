import Stripe from "stripe";

function getStripe(): Stripe {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) throw new Error("STRIPE_SECRET_KEY is not set");
  return new Stripe(key, {
    apiVersion: "2025-02-24.acacia",
    typescript: true,
  });
}

// Lazy singleton — created on first use, not at module load
let _stripe: Stripe | null = null;
export function stripe(): Stripe {
  if (!_stripe) _stripe = getStripe();
  return _stripe;
}

export const PRODUCT_PRICE_CENTS = 7900; // $79.00
export const PRODUCT_NAME = "Texas Hold'em Gym";
export const CURRENCY = "usd";
