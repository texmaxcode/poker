"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

interface BuyButtonProps {
  size?: "sm" | "md" | "lg";
  className?: string;
  label?: string;
}

type State = "idle" | "loading" | "error";

export default function BuyButton({ size = "md", className = "", label }: BuyButtonProps) {
  const [state, setState] = useState<State>("idle");
  const router = useRouter();

  const sizeClasses = {
    sm: "px-5 py-2.5 text-sm",
    md: "px-7 py-3.5 text-base",
    lg: "px-10 py-4 text-lg",
  };

  async function handleBuy() {
    setState("loading");
    try {
      const res = await fetch("/api/checkout", { method: "POST" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      if (data.url) {
        router.push(data.url);
        // keep loading state — page is navigating away
      } else {
        throw new Error("No checkout URL returned");
      }
    } catch (err) {
      console.error("Checkout error:", err);
      setState("error");
      // Auto-reset after 4 seconds so the user can try again
      setTimeout(() => setState("idle"), 4000);
    }
  }

  if (state === "error") {
    return (
      <div className={`flex flex-col items-center gap-1.5 ${className}`}>
        <div className="px-6 py-3 rounded-xl bg-red-900/50 border border-red-700/50 text-red-300 text-sm text-center">
          Something went wrong. Please try again.
        </div>
        <button
          onClick={() => setState("idle")}
          className="text-gold text-xs underline underline-offset-2 hover:text-gold-bright"
        >
          Try again
        </button>
      </div>
    );
  }

  return (
    <button
      type="button"
      data-track="cta_checkout_stripe"
      onClick={handleBuy}
      disabled={state === "loading"}
      aria-busy={state === "loading"}
      className={`
        ${sizeClasses[size]}
        inline-flex items-center justify-center gap-2
        font-button rounded-xl
        bg-gradient-to-r from-gold-bright via-gold to-gold-muted
        text-poker-bg
        hover:from-gold hover:via-gold-bright hover:to-gold
        disabled:opacity-70 disabled:cursor-not-allowed
        shadow-gold hover:shadow-gold-lg
        transition-all duration-200 transform hover:scale-[1.03] active:scale-100
        ${className}
      `}
    >
      {state === "loading" ? (
        <>
          <svg className="animate-spin w-4 h-4 flex-shrink-0" viewBox="0 0 24 24" fill="none">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
          </svg>
          Opening Checkout…
        </>
      ) : (
        label || "Buy Now — $79"
      )}
    </button>
  );
}
