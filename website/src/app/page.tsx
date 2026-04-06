import Image from "next/image";
import Link from "next/link";
import BuyButton from "@/components/BuyButton";
import { MacIcon, PlatformWindowsMacLabel, WindowsIcon } from "@/components/PlatformIcons";

const FEATURES = [
  {
    icon: "♠",
    title: "Play Real Poker Hands",
    desc: "Six-player table against configurable opponents. Set your own stakes and pace. Practice decisions in a realistic game environment.",
  },
  {
    icon: "♦",
    title: "Know Exactly What to Open",
    desc: "Visual range charts for every position at the table. See at a glance which hands to open, call, or fold — colour-coded and interactive.",
  },
  {
    icon: "♣",
    title: "Drill Preflop Until It's Automatic",
    desc: "Flash-card quizzes for every seat and situation. Get instant feedback graded against sound strategy — right, close, or wrong.",
  },
  {
    icon: "♥",
    title: "Practise the Flop, Turn & River",
    desc: "Work through postflop spots and see exactly how many big blinds you leak per session. Identifies leaks you didn't know you had.",
  },
  {
    icon: "♠",
    title: "Check Your Equity in Seconds",
    desc: "Enter your hand, the board, and an opponent range. See your winning odds immediately — no mental arithmetic required.",
  },
  {
    icon: "♦",
    title: "Explore Optimal Play",
    desc: "Built-in solver shows you what balanced, unexploitable strategy looks like for any given spot. Fully local — no subscription required.",
  },
  {
    icon: "♣",
    title: "Track Your Progress",
    desc: "See your win rate, session history, and bankroll chart over time. All data stays on your machine — no cloud account needed.",
  },
  {
    icon: "♥",
    title: "Shape Your Opposition",
    desc: "Tune each opponent's aggression, tightness, and tendencies independently. Build the game you want to beat.",
  },
];

const FAQS = [
  {
    q: "Is this a subscription?",
    a: "$79 once. You own it forever. Poker training sites typically charge $30–50 a month — this pays for itself in two months.",
  },
  {
    q: "Which platforms are supported?",
    a: "Windows and macOS. Both are included in a single purchase — install on every machine you own.",
  },
  {
    q: "Does it need an internet connection?",
    a: "No. Everything runs locally on your computer. No login, no cloud, no data leaves your machine.",
  },
  {
    q: "How do I get the installers?",
    a: "Right after payment you see a confirmation page with Windows and macOS links, and you receive the same links by email. No waiting.",
  },
  {
    q: "What is your refund policy?",
    a: "Email us within 30 days for a full refund. No forms, no questions.",
  },
  {
    q: "Do I get future updates?",
    a: "Bug fixes and minor improvements are free. Major new versions may have an optional upgrade, but you are never forced to update.",
  },
];

const SCREENSHOTS = [
  { src: "/screenshots/table2.png",   caption: "Live table with HUD and bet-sizing controls" },
  { src: "/screenshots/ranges.png",   caption: "Preflop range charts — Call, Raise & Open layers" },
  { src: "/screenshots/training.png", caption: "Training progress and accuracy stats" },
  { src: "/screenshots/solver.png",   caption: "Equity calculator and strategy solver" },
  { src: "/screenshots/stats.png",    caption: "Leaderboard and bankroll chart" },
  { src: "/screenshots/setup.png",    caption: "Opponent style and behaviour settings" },
];

export default function HomePage() {
  return (
    <>
      {/* ── Hero ──────────────────────────────────────────────────────────── */}
      <section className="relative overflow-hidden bg-hero-gradient">
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[900px] h-[500px] rounded-full bg-gold/5 blur-[160px]" />
        </div>
        <div className="absolute bottom-0 left-0 right-0 h-48 bg-gradient-to-t from-poker-bg to-transparent pointer-events-none z-10" />

        <div className="relative z-10 max-w-5xl mx-auto px-4 pt-24 pb-0 text-center">
          {/* Top badge */}
          <div className="inline-flex flex-wrap items-center justify-center gap-x-2 gap-y-1 px-4 py-1.5 rounded-full border border-gold/25 bg-gold/8 text-gold text-sm font-semibold mb-8 tracking-wide">
            <span className="text-xs">♠</span>
            <span className="inline-flex items-center gap-1.5">
              <WindowsIcon className="w-3.5 h-3.5 text-gold" />
              <MacIcon className="w-3.5 h-3.5 text-gold" />
              <span>Windows · macOS</span>
            </span>
            <span className="text-gold/50">·</span>
            <span>One-time $79</span>
          </div>

          {/* Headline */}
          <h1 className="font-rye mb-6 leading-tight">
            <span className="block text-5xl sm:text-6xl lg:text-[72px] text-gold-gradient">
              Texas Hold&apos;em Gym
            </span>
          </h1>

          <p className="text-xl sm:text-2xl text-[#c4b8b0] max-w-2xl mx-auto leading-relaxed mb-10">
            The desktop training app that turns leaky guesses into sharp decisions —
            at the table, in the ranges, on every street.
          </p>

          {/* CTA */}
          <div className="flex flex-col items-center gap-4">
            <BuyButton size="lg" />

            <div className="flex items-center gap-5 flex-wrap justify-center text-sm text-[#9a8e85]">
              <span className="flex items-center gap-1.5"><span className="text-gold text-xs">✓</span> 30-day money-back guarantee</span>
              <span className="hidden sm:inline text-[#3d3028]">·</span>
              <span className="flex items-center gap-1.5"><span className="text-gold text-xs">✓</span> One-time payment</span>
              <span className="hidden sm:inline text-[#3d3028]">·</span>
              <span className="flex items-center gap-1.5"><span className="text-gold text-xs">✓</span> Installers after checkout</span>
            </div>

            <p className="text-xs text-[#9a8e85]">
              Training sites charge $30–50/month.&ensp;
              <span className="text-[#c4b8b0] font-semibold">This is $79 once.</span>
            </p>
          </div>

          {/* Hero screenshot */}
          <div className="mt-16 relative mx-auto max-w-4xl">
            <div className="absolute -inset-px rounded-xl bg-gradient-to-b from-gold/20 via-gold/5 to-transparent pointer-events-none z-10" />
            <div className="absolute -inset-8 bg-felt-mid/20 rounded-3xl blur-3xl pointer-events-none" />
            <div className="screenshot-frame relative">
              <Image
                src="/screenshots/table2.png"
                alt="Texas Hold'em Gym — live poker table with HUD and action controls"
                width={1024}
                height={553}
                className="w-full h-auto"
                priority
              />
            </div>
          </div>
        </div>
      </section>

      {/* ── Trust strip ───────────────────────────────────────────────────── */}
      <section className="border-y border-poker-border bg-poker-panel/60 py-4">
        <div className="max-w-4xl mx-auto px-4 flex flex-wrap items-center justify-center gap-x-8 gap-y-2">
          {["Runs fully offline", "No account or cloud"].map((t) => (
            <span key={t} className="flex items-center gap-2 text-sm text-[#c4b8b0]">
              <span className="w-1 h-1 rounded-full bg-gold inline-block flex-shrink-0" />
              {t}
            </span>
          ))}
          <span className="flex items-center gap-2 text-sm text-[#c4b8b0]">
            <span className="w-1 h-1 rounded-full bg-gold inline-block flex-shrink-0" />
            <PlatformWindowsMacLabel />
          </span>
          {["Secure Stripe checkout", "30-day refund policy"].map((t) => (
            <span key={t} className="flex items-center gap-2 text-sm text-[#c4b8b0]">
              <span className="w-1 h-1 rounded-full bg-gold inline-block flex-shrink-0" />
              {t}
            </span>
          ))}
        </div>
      </section>

      {/* ── Features ──────────────────────────────────────────────────────── */}
      <section id="features" className="py-20 px-4">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-12">
            <h2 className="text-4xl font-black text-gold-gradient font-rye mb-3">
              Stop Guessing. Start Knowing.
            </h2>
            <p className="text-[#c4b8b0] text-lg max-w-xl mx-auto">
              Eight tools in one app — study the game you love, entirely offline.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {FEATURES.map((f) => (
              <div
                key={f.title}
                className="relative bg-poker-panel border border-poker-border rounded-xl p-5 group hover:border-gold/50 hover:bg-poker-elevated transition-all duration-200 overflow-hidden"
              >
                {/* Gold left accent on hover */}
                <div className="absolute left-0 top-0 bottom-0 w-0.5 bg-gold scale-y-0 group-hover:scale-y-100 transition-transform duration-200 origin-center rounded-full" />
                <div className="text-gold font-rye text-lg mb-3 opacity-70 group-hover:opacity-100 transition-opacity">{f.icon}</div>
                <h3 className="font-semibold text-[#f2ebe4] text-sm mb-1.5 leading-snug group-hover:text-gold transition-colors">
                  {f.title}
                </h3>
                <p className="text-[#9a8e85] text-xs leading-relaxed">{f.desc}</p>
              </div>
            ))}
          </div>

          <div className="text-center mt-8">
            <Link href="/features" className="text-gold hover:text-gold-bright transition-colors text-sm underline underline-offset-4">
              Detailed walkthrough with screenshots →
            </Link>
          </div>
        </div>
      </section>

      <div className="section-divider" />

      {/* ── Screenshots ───────────────────────────────────────────────────── */}
      <section id="screenshots" className="py-20 px-4">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-12">
            <h2 className="text-4xl font-black text-gold-gradient font-rye mb-3">
              Built for Serious Study
            </h2>
            <p className="text-[#c4b8b0] text-lg max-w-xl mx-auto">
              A focused, dark interface that respects your time and gets out of the way.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {SCREENSHOTS.map((s) => (
              <div key={s.src} className="group">
                <div className="screenshot-frame transition-transform duration-300 group-hover:scale-[1.02] group-hover:shadow-gold">
                  <Image src={s.src} alt={s.caption} width={1024} height={553} className="w-full h-auto" />
                </div>
                <p className="text-[#9a8e85] text-xs mt-2 text-center">{s.caption}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <div className="section-divider" />

      {/* ── Pricing ───────────────────────────────────────────────────────── */}
      <section id="pricing" className="py-20 px-4">
        <div className="max-w-sm mx-auto">
          <div className="text-center mb-10">
            <h2 className="text-4xl font-black text-gold-gradient font-rye mb-3">
              One Price. Own It Forever.
            </h2>
            <p className="text-[#c4b8b0]">
              Training sites charge $30–50/month.{" "}
              <span className="text-[#f2ebe4] font-semibold">Texas Hold&apos;em Gym is $79 once.</span>
            </p>
          </div>

          <div className="relative">
            <div className="absolute -inset-1.5 bg-gold/15 rounded-2xl blur-xl pointer-events-none" />
            <div className="relative bg-poker-panel border border-gold/35 rounded-2xl p-8 shadow-card">
              <div className="text-center mb-6">
                <div className="text-gold text-[11px] font-semibold uppercase tracking-[0.15em] mb-3">Full License · All Platforms</div>
                <div className="flex items-baseline justify-center gap-1 mb-1">
                  <span className="text-[#9a8e85] text-xl leading-none">$</span>
                  <span className="text-7xl font-black text-white leading-none font-rye">79</span>
                </div>
                <div className="text-[#9a8e85] text-sm">one-time · no subscription</div>
              </div>

              <BuyButton size="lg" className="w-full justify-center mb-3" />
              <p className="text-[#9a8e85] text-xs text-center mb-6">Secure checkout via Stripe · Installer links sent immediately</p>

              <div className="section-divider mb-5" />

              <ul className="space-y-2.5">
                {[
                  "Live poker table with 5 bot opponents",
                  "Preflop decision drills — every seat & mode",
                  "Flop, turn & river drills with mistake tracking",
                  "Range charts for every position",
                  "Equity calculator",
                  "Pot odds calculator",
                  "Strategy solver",
                  "Win-rate tracker and bankroll history",
                  "Free updates",
                  "30-day money-back guarantee",
                ].map((item) => (
                  <li key={item} className="flex items-start gap-3 text-[#c4b8b0] text-sm">
                    <span className="text-gold flex-shrink-0 mt-0.5 text-xs">✓</span>
                    {item}
                  </li>
                ))}
                <li className="flex items-start gap-3 text-[#c4b8b0] text-sm">
                  <span className="text-gold flex-shrink-0 mt-0.5 text-xs">✓</span>
                  <span className="inline-flex items-center gap-2 flex-wrap">
                    <WindowsIcon className="w-4 h-4 text-gold flex-shrink-0" />
                    <MacIcon className="w-4 h-4 text-gold flex-shrink-0" />
                    <span>Windows &amp; macOS — one license, both platforms</span>
                  </span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      <div className="section-divider" />

      {/* ── FAQ ───────────────────────────────────────────────────────────── */}
      <section id="faq" className="py-20 px-4">
        <div className="max-w-2xl mx-auto">
          <div className="text-center mb-10">
            <h2 className="text-4xl font-black text-gold-gradient font-rye mb-3">
              Questions
            </h2>
          </div>
          <div className="space-y-3">
            {FAQS.map((faq) => (
              <div key={faq.q} className="bg-poker-panel border border-poker-border rounded-xl p-5 hover:border-gold/30 transition-colors">
                <h3 className="font-semibold text-[#f2ebe4] text-sm mb-1.5">{faq.q}</h3>
                <p className="text-[#c4b8b0] text-sm leading-relaxed">{faq.a}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── Final CTA ─────────────────────────────────────────────────────── */}
      <section className="py-20 px-4 text-center border-t border-poker-border">
        <div className="max-w-xl mx-auto">
          <div className="text-3xl mb-5 text-gold/60 font-rye select-none">♠ ♦ ♣ ♥</div>
          <h2 className="text-3xl font-black text-gold-gradient font-rye mb-4">
            Ready to Plug the Leaks?
          </h2>
          <p className="text-[#c4b8b0] text-lg mb-8">
            One purchase. Every tool to sharpen your game — all yours, forever.
          </p>
          <BuyButton size="lg" />
          <p className="text-[#9a8e85] text-sm mt-4">30-day money-back guarantee · Instant access to installers</p>
        </div>
      </section>
    </>
  );
}
