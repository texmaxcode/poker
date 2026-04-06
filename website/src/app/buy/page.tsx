import type { Metadata } from "next";
import BuyButton from "@/components/BuyButton";

export const metadata: Metadata = {
  title: "Buy Texas Hold'em Gym",
  description: "Purchase Texas Hold'em Gym for $79 — one-time payment, all platforms.",
};

export default function BuyPage() {
  return (
    <div className="min-h-[60vh] flex items-center justify-center px-4 py-16">
      <div className="text-center max-w-md">
        <div className="text-5xl mb-6">♠</div>
        <h1 className="text-4xl font-black text-gold-gradient mb-4 font-rye">
          Ready to Buy?
        </h1>
        <p className="text-[#a89890] mb-2">
          You&apos;ll be redirected to Stripe&apos;s secure checkout page.
        </p>
        <p className="text-[#7a7068] text-sm mb-8">
          $79 one-time · All platforms · 30-day refund guarantee
        </p>
        <BuyButton size="lg" label="Proceed to Checkout — $79" />
        <p className="text-[#7a7068] text-xs mt-4">
          Secure payment processed by Stripe. We never store your card details.
        </p>
      </div>
    </div>
  );
}
