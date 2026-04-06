import type { Metadata } from "next";
import { Rye, Merriweather, Roboto_Mono, Holtwood_One_SC } from "next/font/google";
import "./globals.css";
import SiteChrome from "@/components/SiteChrome";

const rye = Rye({
  weight: "400",
  subsets: ["latin"],
  variable: "--font-rye",
  display: "swap",
});

const merriweather = Merriweather({
  weight: ["300", "400", "700", "900"],
  subsets: ["latin"],
  variable: "--font-merriweather",
  display: "swap",
});

const holtwoodOneSC = Holtwood_One_SC({
  weight: "400",
  subsets: ["latin"],
  variable: "--font-holtwood",
  display: "swap",
});

const robotoMono = Roboto_Mono({
  weight: ["400", "500", "700"],
  subsets: ["latin"],
  variable: "--font-mono",
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "Texas Hold'em Gym — Desktop Poker Training App",
    template: "%s | Texas Hold'em Gym",
  },
  description:
    "Practice 6-max No-Limit Hold'em against smart bots, study preflop/postflop ranges, run equity simulations, and track your progress. One-time purchase, all platforms.",
  keywords: ["poker training", "texas holdem", "poker software", "GTO", "poker practice", "range training"],
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || "https://texasholdemgym.com"),
  openGraph: {
    title: "Texas Hold'em Gym — Desktop Poker Training App",
    description:
      "Practice 6-max NLHE against bots, study ranges, run equity sims, and track improvement. One-time $79.",
    type: "website",
    images: ["/screenshots/lobby.png"],
  },
  twitter: {
    card: "summary_large_image",
    title: "Texas Hold'em Gym",
    description: "Serious desktop poker training. One-time $79.",
    images: ["/screenshots/lobby.png"],
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html
      lang="en"
      className={`scroll-smooth ${rye.variable} ${merriweather.variable} ${holtwoodOneSC.variable} ${robotoMono.variable}`}
    >
      <body className="min-h-screen flex flex-col font-body">
        <SiteChrome>{children}</SiteChrome>
      </body>
    </html>
  );
}
