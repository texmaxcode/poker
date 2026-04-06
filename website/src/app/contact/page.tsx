import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Contact & Support",
  description: "Get help with Texas Hold'em Gym — purchase support, technical issues, refunds.",
};

const TOPICS = [
  {
    icon: "📦",
    title: "Purchase & installers",
    desc: "Didn't receive your Windows or macOS installer links? Send us the email address you used to pay and we'll sort it out right away.",
    email: "support@texasholdemgym.com",
  },
  {
    icon: "💰",
    title: "Refunds",
    desc: "We offer a 30-day money-back guarantee, no questions asked. Email us from the address used for purchase.",
    email: "support@texasholdemgym.com",
  },
  {
    icon: "🐛",
    title: "Bug Reports",
    desc: "Found a bug? Describe what happened, your OS version, and how to reproduce it.",
    email: "support@texasholdemgym.com",
  },
  {
    icon: "🔒",
    title: "Privacy & Data",
    desc: "Requests to view or delete your personal data stored in our system.",
    email: "privacy@texasholdemgym.com",
  },
];

export default function ContactPage() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-16">
      <div className="text-center mb-14">
        <h1 className="text-5xl font-black text-gold-gradient mb-4 font-rye">
          Contact & Support
        </h1>
        <p className="text-[#a89890] text-lg">
          We aim to respond to all emails within 24 hours on business days.
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-5 mb-12">
        {TOPICS.map((t) => (
          <div key={t.title} className="bg-poker-panel border border-poker-border rounded-xl p-6">
            <div className="text-3xl mb-3">{t.icon}</div>
            <h2 className="text-white font-bold mb-2">{t.title}</h2>
            <p className="text-[#7a7068] text-sm leading-relaxed mb-4">{t.desc}</p>
            <a
              href={`mailto:${t.email}?subject=${encodeURIComponent(t.title)}`}
              className="text-gold hover:text-gold-bright text-sm font-semibold transition-colors"
            >
              {t.email} →
            </a>
          </div>
        ))}
      </div>

      <div className="bg-poker-panel border border-gold/20 rounded-xl p-6 text-center">
        <p className="text-[#a89890] text-sm mb-1">General enquiries</p>
        <a
          href="mailto:support@texasholdemgym.com"
          className="text-gold text-lg font-semibold hover:text-gold-bright transition-colors"
        >
          support@texasholdemgym.com
        </a>
        <p className="text-[#7a7068] text-xs mt-3">
          Not a customer yet?{" "}
          <Link href="/pricing" className="text-gold hover:text-gold-light transition-colors">
            See pricing →
          </Link>
        </p>
      </div>
    </div>
  );
}
