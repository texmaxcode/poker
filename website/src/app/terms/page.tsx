import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms of Service",
};

export default function TermsPage() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-16">
      <h1 className="text-4xl font-black text-gold-gradient mb-2 font-rye">
        Terms of Service
      </h1>
      <p className="text-[#7a7068] text-sm mb-10">Last updated: April 2026</p>

      <div className="space-y-8 text-[#c4b8b0] leading-relaxed">
        <section>
          <h2 className="text-white font-bold text-xl mb-3">1. License</h2>
          <p>
            Upon purchasing Texas Hold&apos;em Gym you receive a <strong className="text-white">perpetual, non-exclusive,
            non-transferable</strong> license to install and use the software on your own personal devices.
            You may not resell, sublicense, rent, or redistribute the software.
          </p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">2. Payment</h2>
          <p>
            Texas Hold&apos;em Gym is sold as a one-time purchase with no recurring fees.
            All payments are processed securely by Stripe. We do not store your card details.
          </p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">3. Refunds</h2>
          <p>
            We offer a <strong className="text-white">30-day money-back guarantee</strong>.
            If you&apos;re unsatisfied for any reason, email us within 30 days of purchase and
            we will issue a full refund. Refunds are processed through Stripe and typically appear within 5–10 business days.
          </p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">4. Updates</h2>
          <p>
            Minor updates and bug fixes are provided free of charge. Major new feature versions may be offered
            at an optional upgrade price. You are never required to update.
          </p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">5. Disclaimer</h2>
          <p>
            Texas Hold&apos;em Gym is an educational and entertainment tool for learning poker strategy.
            It is <strong className="text-white">not a gambling platform</strong> and does not involve real money wagering.
            All in-app currency is simulated.
          </p>
          <p className="mt-2">
            The software is provided &quot;as is&quot; without warranties of any kind. We are not liable for
            any indirect, incidental, or consequential damages arising from the use of the software.
          </p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">6. Intellectual Property</h2>
          <p>
            All content, code, graphics, and game assets are the exclusive property of the developer.
            Reverse engineering, decompiling, or modifying the software is prohibited.
          </p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">7. Governing Law</h2>
          <p>
            These terms are governed by the laws of the applicable jurisdiction. Any disputes will be
            handled through good-faith negotiation, and if necessary, binding arbitration.
          </p>
        </section>

        <section>
          <h2 className="text-white font-bold text-xl mb-3">8. Contact</h2>
          <p>
            Questions about these terms?{" "}
            <a href="mailto:support@texasholdemgym.com" className="text-gold hover:text-gold-light">
              support@texasholdemgym.com
            </a>
          </p>
        </section>
      </div>
    </div>
  );
}
