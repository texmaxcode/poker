import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import BuyButton from "@/components/BuyButton";

export const metadata: Metadata = {
  title: "Features",
  description: "Explore every feature of Texas Hold'em Gym — live table, preflop and postflop drills, range charts, equity calculator, and strategy solver.",
};

const SECTIONS = [
  {
    img: "/screenshots/table2.png",
    title: "Play Live Hands at Your Own Pace",
    flip: false,
    points: [
      "Six-player No-Limit Hold'em with realistic betting, side pots, and all-ins",
      "Five opponents with individual styles — configure each one independently",
      "Set your own stakes, buy-in amounts, and how long each player has to act",
      "Action controls right at your seat: fold, call, raise, or pick a bet size with one click",
      "Pause or resume any time — bots sit out when you need a break",
    ],
  },
  {
    img: "/screenshots/ranges.png",
    title: "See Every Preflop Decision at a Glance",
    flip: true,
    points: [
      "Colour-coded hand charts showing open, call, and raise frequencies for every seat",
      "Composite view layers all three on top of each other so nothing is hidden",
      "Hover any hand to see the exact split: how often to fold, call, raise, or open",
      "Edit the charts by clicking and dragging — test your own strategy adjustments",
      "Export any range as plain text or import from a text string",
    ],
  },
  {
    img: "/screenshots/training.png",
    title: "Drill Until the Right Play Is Instinct",
    flip: false,
    points: [
      "Preflop flash-card drills for all six seats — open, call, and re-raise spots",
      "Postflop spots on the flop, turn, and river with multiple bet-size options",
      "Each answer is graded: correct, close, or wrong — based on sound strategy",
      "See how many big blinds you lose per session from mistakes — exact numbers",
      "Set a decision clock and auto-advance delay to simulate real pressure",
    ],
  },
  {
    img: "/screenshots/solver.png",
    title: "Calculate Equity and Find the Right Play",
    flip: true,
    points: [
      "Enter your cards, the board, and an opponent's likely holdings — get your winning percentage instantly",
      "Pot odds mode: type the pot and the bet to see exactly how often you need to win",
      "Strategy solver shows balanced, unexploitable play for benchmark game trees",
      "Full output log you can copy — useful for reviewing spots after a session",
    ],
  },
  {
    img: "/screenshots/stats.png",
    title: "Watch Your Game Improve Over Time",
    flip: false,
    points: [
      "Ranked table showing total stack, session profit/loss, and overall win rate",
      "Continuous bankroll chart — see every swing across every session you've played",
      "Reset session stats without losing your historical record",
      "All data lives in a local file on your computer — nothing is uploaded anywhere",
    ],
  },
  {
    img: "/screenshots/setup.png",
    title: "Configure the Game You Want to Beat",
    flip: true,
    points: [
      "Six named opponents, each with their own wallet and a preset starting style",
      "Strategy profiles: balanced, tight, loose, aggressive, and more",
      "Fine-tune how often each opponent bluffs, 3-bets, or folds to pressure",
      "Toggle any bot on or off mid-session without stopping the game",
    ],
  },
];

export default function FeaturesPage() {
  return (
    <div className="max-w-6xl mx-auto px-4 py-16">
      {/* Header */}
      <div className="text-center mb-14">
        <h1 className="text-5xl font-black text-gold-gradient font-rye mb-4">Features</h1>
        <p className="text-[#c4b8b0] text-xl max-w-2xl mx-auto">
          Every tool you need to study No-Limit Hold&apos;em — in one offline app.
        </p>
      </div>

      {/* Feature sections */}
      <div className="space-y-20">
        {SECTIONS.map((s) => (
          <div
            key={s.title}
            className={`flex flex-col ${s.flip ? "lg:flex-row-reverse" : "lg:flex-row"} items-center gap-10`}
          >
            <div className="flex-1 w-full min-w-0">
              <div className="screenshot-frame group hover:shadow-gold transition-shadow duration-300">
                <Image src={s.img} alt={s.title} width={1024} height={553} className="w-full h-auto" />
              </div>
            </div>
            <div className="flex-1 lg:max-w-[420px] min-w-0">
              <h2 className="text-2xl font-black text-white font-rye mb-5 leading-snug">{s.title}</h2>
              <ul className="space-y-3">
                {s.points.map((p) => (
                  <li key={p} className="flex items-start gap-3 text-[#c4b8b0] text-sm leading-relaxed">
                    <span className="text-gold text-xs mt-1 flex-shrink-0">✓</span>
                    {p}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        ))}
      </div>

      {/* CTA */}
      <div className="text-center mt-16 pt-12 border-t border-poker-border">
        <h2 className="text-3xl font-black text-gold-gradient font-rye mb-3">Get the Full App</h2>
        <p className="text-[#c4b8b0] mb-8">One-time $79 · All platforms · No subscription.</p>
        <div className="flex items-center justify-center gap-4 flex-wrap">
          <BuyButton size="lg" />
          <Link href="/pricing" className="text-gold hover:text-gold-bright transition-colors underline underline-offset-4 text-sm">
            See what&apos;s included →
          </Link>
        </div>
      </div>
    </div>
  );
}
