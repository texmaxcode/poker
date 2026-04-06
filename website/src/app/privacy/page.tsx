import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy",
};

export default function PrivacyPage() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-16 prose prose-invert prose-gold">
      <h1 className="text-4xl font-black text-gold-gradient mb-2 font-rye">
        Privacy Policy
      </h1>
      <p className="text-[#7a7068] text-sm mb-10">Last updated: April 2026</p>

      <div className="space-y-8 text-[#c4b8b0] leading-relaxed">
        <section>
          <h2 className="text-white font-bold text-xl mb-3">1. What We Collect</h2>
          <p>
            When you make a purchase we collect your <strong className="text-white">email address</strong> and
            payment data via Stripe. We do <em>not</em> store card numbers — Stripe handles all payment processing.
          </p>
          <p className="mt-2">
            We store your email address and purchase record (Stripe session ID, amount, date) in our database
            solely to send you installer links (Windows and macOS) and provide purchase support.
          </p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">2. The Desktop App</h2>
          <p>
            Texas Hold&apos;em Gym is a fully <strong className="text-white">offline</strong> application.
            It stores all your data (game state, training progress, bankroll) locally on your machine in
            SQLite. <strong className="text-white">No telemetry, no analytics, no network calls</strong> are
            made by the app itself.
          </p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">3. How We Use Your Email</h2>
          <ul className="list-disc list-inside space-y-1 ml-2">
            <li>Send your Windows and macOS installer links immediately after purchase</li>
            <li>Provide customer support when you contact us</li>
          </ul>
          <p className="mt-2">We do <strong className="text-white">not</strong> send marketing emails or sell your address to anyone.</p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">4. Third-Party Services</h2>
          <ul className="list-disc list-inside space-y-1 ml-2">
            <li><strong className="text-white">Stripe</strong> — payment processing (<a href="https://stripe.com/privacy" className="text-gold hover:text-gold-light">stripe.com/privacy</a>)</li>
            <li><strong className="text-white">Resend</strong> — transactional email delivery</li>
            <li><strong className="text-white">AWS S3 / CloudFront</strong> — download file hosting</li>
          </ul>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">5. Data Retention</h2>
          <p>
            Purchase records are kept indefinitely so we can verify purchases and support customers.
            Email us if you want your record deleted — we&apos;ll handle it within 7 days.
          </p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">6. Your Rights</h2>
          <p>
            You may request a copy of the data we hold about you, or ask us to delete it,
            by emailing <a href="mailto:privacy@texasholdemgym.com" className="text-gold hover:text-gold-light">privacy@texasholdemgym.com</a>.
          </p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">7. Changes</h2>
          <p>
            We may update this policy occasionally. Any significant changes will be noted at the top of this page.
          </p>
        </section>
      </div>
    </div>
  );
}
