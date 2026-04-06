import Link from "next/link";

export default function Footer() {
  return (
    <footer className="border-t border-poker-border bg-poker-bg mt-auto">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8 mb-10">
          <div className="md:col-span-2">
            <div className="text-gold-bright font-bold text-xl mb-3 font-rye">
              Texas Hold&apos;em Gym
            </div>
            <p className="text-[#7a7068] text-sm leading-relaxed max-w-xs">
              A serious desktop training tool for 6-max No-Limit Hold&apos;em. Practice hands, study ranges, and sharpen your edge.
            </p>
          </div>
          <div>
            <div className="text-gold text-sm font-semibold mb-3 uppercase tracking-wider">Product</div>
            <ul className="space-y-2 text-sm">
              <li><Link href="/features" data-track="footer_features" className="text-[#7a7068] hover:text-gold transition-colors">Features</Link></li>
              <li><Link href="/pricing" data-track="footer_pricing" className="text-[#7a7068] hover:text-gold transition-colors">Pricing</Link></li>
              <li><Link href="/download" data-track="footer_download" className="text-[#7a7068] hover:text-gold transition-colors">Download</Link></li>
            </ul>
          </div>
          <div>
            <div className="text-gold text-sm font-semibold mb-3 uppercase tracking-wider">Legal</div>
            <ul className="space-y-2 text-sm">
              <li><Link href="/privacy" data-track="footer_privacy" className="text-[#7a7068] hover:text-gold transition-colors">Privacy Policy</Link></li>
              <li><Link href="/terms" data-track="footer_terms" className="text-[#7a7068] hover:text-gold transition-colors">Terms of Service</Link></li>
              <li><Link href="/contact" data-track="footer_contact" className="text-[#7a7068] hover:text-gold transition-colors">Contact</Link></li>
            </ul>
          </div>
        </div>

        <div className="section-divider mb-6" />

        <div className="flex flex-col md:flex-row items-center justify-between gap-3 text-xs text-[#9a8e85]">
          <p>© {new Date().getFullYear()} Texas Hold&apos;em Gym. All rights reserved.</p>
          <div className="flex items-center gap-4">
            <span>One-time purchase. No subscription.</span>
            <span>•</span>
            <span>Windows · macOS · Linux</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
