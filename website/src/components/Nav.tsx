"use client";

import Link from "next/link";
import { useState } from "react";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/features", label: "Features" },
  { href: "/pricing",  label: "Pricing" },
  { href: "/download", label: "Download" },
  { href: "/contact",  label: "Support" },
];

export default function Nav() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  function isActive(href: string) {
    return pathname === href || pathname.startsWith(href + "/");
  }

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 border-b border-poker-border bg-poker-bg/95 backdrop-blur-sm">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link href="/" data-track="nav_logo_home" className="group flex items-center gap-2 flex-shrink-0">
            <span className="text-gold-bright font-rye text-xl tracking-wide group-hover:text-white transition-colors">
              Texas Hold&apos;em Gym
            </span>
          </Link>

          {/* Desktop links */}
          <div className="hidden md:flex items-center gap-1">
            {LINKS.map(({ href, label }) => (
              <Link
                key={href}
                href={href}
                data-track={`nav_${href.replace(/^\//, "").replace(/\//g, "_") || "home"}`}
                className={`px-3 py-2 rounded-lg text-sm transition-colors ${
                  isActive(href)
                    ? "text-gold bg-gold/10"
                    : "text-[#c4b8b0] hover:text-[#f2ebe4] hover:bg-white/5"
                }`}
              >
                {label}
              </Link>
            ))}

            {/* Nav CTA — outline style so hero CTA remains primary */}
            <Link
              href="/buy"
              data-track="nav_buy_outline"
              className="ml-3 px-5 py-2 rounded-lg text-sm font-semibold border border-gold/60 text-gold hover:bg-gold hover:text-poker-bg transition-all"
            >
              Buy — $79
            </Link>
          </div>

          {/* Mobile hamburger */}
          <button
            className="md:hidden text-[#c4b8b0] hover:text-gold transition-colors p-2 rounded-lg"
            onClick={() => setOpen(!open)}
            aria-label="Toggle menu"
            aria-expanded={open}
          >
            {open ? (
              <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            ) : (
              <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            )}
          </button>
        </div>
      </div>

      {/* Mobile menu — animated */}
      <div
        className={`md:hidden border-t border-poker-border bg-poker-panel overflow-hidden transition-all duration-200 ${
          open ? "max-h-96 opacity-100" : "max-h-0 opacity-0"
        }`}
      >
        <div className="px-4 py-4 space-y-1">
          {LINKS.map(({ href, label }) => (
            <Link
              key={href}
              href={href}
              data-track={`nav_mobile_${href.replace(/^\//, "").replace(/\//g, "_") || "home"}`}
              className={`block px-3 py-2.5 rounded-lg text-sm transition-colors ${
                isActive(href)
                  ? "text-gold bg-gold/10"
                  : "text-[#c4b8b0] hover:text-[#f2ebe4] hover:bg-white/5"
              }`}
              onClick={() => setOpen(false)}
            >
              {label}
            </Link>
          ))}
          <Link
            href="/buy"
            data-track="nav_mobile_buy_solid"
            className="block w-full text-center mt-2 px-5 py-3 rounded-xl font-semibold text-poker-bg bg-gold hover:bg-gold-bright transition-colors font-button"
            onClick={() => setOpen(false)}
          >
            Buy Now — $79
          </Link>
        </div>
      </div>
    </nav>
  );
}
