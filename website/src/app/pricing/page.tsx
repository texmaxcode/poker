import type { Metadata } from "next";
import Link from "next/link";
import BuyButton from "@/components/BuyButton";

export const metadata: Metadata = {
  title: "Pricing",
  description: "Texas Hold'em Gym — $79 one-time purchase. No subscription. Windows, macOS, and Linux included.",
};

const INCLUDES = [
  "Live poker table with 5 bot opponents",
  "Preflop decision drills for every seat and mode",
  "Flop, turn & river drills with mistake tracking",
  "Range charts for every position",
  "Equity calculator",
  "Pot odds and profitability calculator",
  "Strategy solver",
  "Win-rate tracker and bankroll history",
  "Windows, macOS & Linux",
  "Free updates",
  "30-day money-back guarantee",
];

const REASONS = [
  {
    icon: "♠",
    title: "No Subscription — Ever",
    desc: "Pay $79 once and own it permanently. No monthly bills, no expiry date, no license keys to manage.",
  },
  {
    icon: "♦",
    title: "Every Platform Included",
    desc: "Windows, macOS, and Linux. One purchase covers every machine you own — no extra fees per device.",
  },
  {
    icon: "♣",
    title: "Fully Offline & Private",
    desc: "Everything runs on your own computer. No cloud account, no telemetry. Your game data stays yours.",
  },
  {
    icon: "♥",
    title: "30-Day Money-Back Guarantee",
    desc: "Not satisfied for any reason? Email us within 30 days and we'll refund you in full. No forms, no questions.",
  },
  {
    icon: "♠",
    title: "Download Immediately",
    desc: "After payment you see a download page in your browser and receive an email with links for all platforms.",
  },
];

export default function PricingPage() {
  return (
    <div className="max-w-5xl mx-auto px-4 py-16">
      <div className="text-center mb-14">
        <h1 className="text-5xl font-black text-gold-gradient font-rye mb-4">Pricing</h1>
        <p className="text-[#c4b8b0] text-xl max-w-lg mx-auto">
          Poker training sites charge $30–50 a month.
          <br />
          <span className="text-[#f2ebe4] font-semibold">Texas Hold&apos;em Gym is $79 once.</span>
        </p>
      </div>

      <div className="flex flex-col lg:flex-row gap-10 items-start justify-center">
        {/* Pricing card */}
        <div className="relative w-full max-w-sm mx-auto lg:mx-0 flex-shrink-0">
          <div className="absolute -inset-1.5 bg-gold/15 rounded-2xl blur-xl pointer-events-none" />
          <div className="relative bg-poker-panel border border-gold/35 rounded-2xl p-8 shadow-card">
            <div className="text-center mb-6">
              <div className="inline-flex items-center gap-1.5 bg-gold/15 text-gold text-[11px] font-semibold uppercase tracking-[0.15em] px-3 py-1.5 rounded-full mb-4">
                <span>♠</span> Full License · All Platforms
              </div>
              <div className="flex items-baseline justify-center gap-1 mb-1">
                <span className="text-[#9a8e85] text-xl">$</span>
                <span className="text-7xl font-black text-white font-rye">79</span>
              </div>
              <div className="text-[#9a8e85] text-sm">one-time · no subscription ever</div>
            </div>

            <BuyButton size="lg" className="w-full justify-center mb-3" />
            <p className="text-[#9a8e85] text-xs text-center mb-6">Secure checkout · Download link sent instantly</p>

            <div className="section-divider mb-5" />

            <ul className="space-y-2.5">
              {INCLUDES.map((item) => (
                <li key={item} className="flex items-start gap-3 text-[#c4b8b0] text-sm">
                  <span className="text-gold flex-shrink-0 mt-0.5 text-xs">✓</span>
                  {item}
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Reasons */}
        <div className="flex-1 space-y-4 max-w-md">
          {REASONS.map((r) => (
            <div key={r.title} className="bg-poker-panel border border-poker-border rounded-xl p-5 hover:border-gold/30 transition-colors">
              <h3 className="text-[#f2ebe4] font-semibold mb-1.5 flex items-center gap-2 text-sm">
                <span className="text-gold font-rye">{r.icon}</span> {r.title}
              </h3>
              <p className="text-[#c4b8b0] text-sm leading-relaxed">{r.desc}</p>
            </div>
          ))}
          <p className="text-center text-sm text-[#9a8e85] pt-1">
            Questions before buying?{" "}
            <Link href="/contact" className="text-gold hover:text-gold-bright transition-colors">
              Contact us →
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
