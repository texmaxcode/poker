import type { Metadata } from "next";
import Link from "next/link";
import { DOWNLOAD_LINKS } from "@/lib/downloads";

export const metadata: Metadata = {
  title: "Purchase Complete — Download Texas Hold'em Gym",
  description: "Your purchase is confirmed. Download Texas Hold'em Gym for Windows, macOS, or Linux.",
};

interface InstallStep {
  platform: string;
  icon: string;
  label: string;
  href: string;
  steps: string[];
}

const PLATFORMS: InstallStep[] = [
  {
    platform: "Windows",
    icon: "🪟",
    label: "Download for Windows (.exe)",
    href: DOWNLOAD_LINKS.windows,
    steps: [
      "Run the downloaded .exe installer",
      'Click "Next" through the setup wizard',
      "Launch Texas Hold'em Gym from the Start Menu",
    ],
  },
  {
    platform: "macOS",
    icon: "🍎",
    label: "Download for macOS (.dmg)",
    href: DOWNLOAD_LINKS.mac,
    steps: [
      "Open the downloaded .dmg file.",
      "Drag Texas Hold'em Gym into Applications.",
      "Right-click the app and choose Open the first time you launch it.",
    ],
  },
  {
    platform: "Linux",
    icon: "🐧",
    label: "Download for Linux (.AppImage)",
    href: DOWNLOAD_LINKS.linux,
    steps: [
      "Open a terminal in the folder where you downloaded the file.",
      "Make it runnable: chmod +x texas-holdem-gym-linux.AppImage",
      "Launch it: ./texas-holdem-gym-linux.AppImage",
    ],
  },
];

export default function SuccessPage() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-16">
      {/* Header */}
      <div className="text-center mb-12">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-gold/20 border border-gold/40 text-3xl mb-6">
          ✓
        </div>
        <h1 className="text-4xl font-black text-gold-gradient mb-3 font-rye">
          Purchase Complete!
        </h1>
        <p className="text-[#a89890] text-lg">
          Thank you for buying Texas Hold&apos;em Gym. Download links have been sent to your email.
        </p>
      </div>

      {/* Download buttons */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-12">
        {PLATFORMS.map((p) => (
          <a
            key={p.platform}
            href={p.href}
            className="flex flex-col items-center gap-3 bg-poker-panel border border-gold/30 rounded-xl p-5 hover:border-gold hover:bg-gold/5 transition-all group"
          >
            <span className="text-4xl">{p.icon}</span>
            <span className="text-gold font-semibold text-sm text-center group-hover:text-gold-bright transition-colors">
              {p.label}
            </span>
          </a>
        ))}
      </div>

      {/* Install instructions */}
      <div className="space-y-4 mb-12">
        <h2 className="text-xl font-bold text-white font-rye">
          Installation Instructions
        </h2>
        {PLATFORMS.map((p) => (
          <div key={p.platform} className="bg-poker-panel border border-poker-border rounded-xl p-5">
            <div className="flex items-center gap-2 mb-3">
              <span className="text-xl">{p.icon}</span>
              <span className="font-semibold text-white">{p.platform}</span>
            </div>
            <ol className="space-y-1.5">
              {p.steps.map((step, i) => (
                <li key={i} className="flex items-start gap-2 text-[#c4b8b0] text-sm">
                  <span className="text-gold font-bold mt-0.5 flex-shrink-0">{i + 1}.</span>
                  {step}
                </li>
              ))}
            </ol>
          </div>
        ))}
      </div>

      {/* Support note */}
      <div className="bg-poker-panel border border-poker-border rounded-xl p-5 text-center">
        <p className="text-[#7a7068] text-sm">
          Questions or issues?{" "}
          <Link href="/contact" className="text-gold hover:text-gold-light transition-colors">
            Contact support
          </Link>{" "}
          — we&apos;re happy to help.
        </p>
      </div>
    </div>
  );
}
