import type { Metadata } from "next";
import Link from "next/link";
import { DOWNLOAD_LINKS } from "@/lib/downloads";

export const metadata: Metadata = {
  title: "Download",
  description:
    "Download the latest version of Texas Hold'em Gym for Windows, macOS, or Linux.",
};

export default function DownloadPage() {
  const platforms = [
    {
      name: "Windows",
      icon: "🪟",
      file: ".exe installer",
      href: DOWNLOAD_LINKS.windows,
      steps: [
        "Run the .exe installer",
        "Follow the setup wizard",
        "Launch from Start Menu",
      ],
    },
    {
      name: "macOS",
      icon: "🍎",
      file: ".dmg disk image",
      href: DOWNLOAD_LINKS.mac,
      steps: [
        "Open the .dmg",
        "Drag to Applications",
        "Right-click → Open on first run",
      ],
    },
    {
      name: "Linux",
      icon: "🐧",
      file: ".AppImage",
      href: DOWNLOAD_LINKS.linux,
      steps: [
        "chmod +x texas-holdem-gym-linux.AppImage",
        "./texas-holdem-gym-linux.AppImage",
      ],
    },
  ];

  return (
    <div className="max-w-4xl mx-auto px-4 py-16">
      <div className="text-center mb-14">
        <h1 className="text-5xl font-black text-gold-gradient mb-4 font-rye">
          Download
        </h1>
        <p className="text-[#a89890] text-lg max-w-xl mx-auto">
          Get the latest version of Texas Hold&apos;em Gym. Already purchased? Download any platform — your license covers all three.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
        {platforms.map((p) => (
          <div key={p.name} className="bg-poker-panel border border-poker-border rounded-xl p-6 flex flex-col">
            <div className="text-4xl mb-3">{p.icon}</div>
            <h2 className="text-white font-bold text-lg mb-1">{p.name}</h2>
            <p className="text-[#7a7068] text-xs mb-4">{p.file}</p>
            <ul className="space-y-1.5 mb-6 flex-1">
              {p.steps.map((step, i) => (
                <li key={i} className="text-[#a89890] text-xs flex items-start gap-2">
                  <span className="text-gold mt-0.5 flex-shrink-0">{i + 1}.</span>
                  <code className="break-all">{step}</code>
                </li>
              ))}
            </ul>
            <a
              href={p.href}
              className="block text-center py-3 rounded-lg font-semibold text-sm bg-gold/20 text-gold border border-gold/30 hover:bg-gold hover:text-poker-bg transition-all"
            >
              Download for {p.name}
            </a>
          </div>
        ))}
      </div>

      <div className="text-center bg-poker-panel border border-poker-border rounded-xl p-6">
        <p className="text-[#a89890] text-sm">
          Haven&apos;t purchased yet?{" "}
          <Link href="/pricing" className="text-gold hover:text-gold-light transition-colors">
            Get Texas Hold&apos;em Gym for $79 →
          </Link>
        </p>
      </div>
    </div>
  );
}
