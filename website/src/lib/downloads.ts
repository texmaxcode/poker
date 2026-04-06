const BASE = process.env.NEXT_PUBLIC_DOWNLOAD_BASE_URL || "https://downloads.texasholdemgym.com";

/** Installers for Stripe success page & post-purchase email (Windows + macOS only). */
export const DOWNLOAD_LINKS = {
  windows: `${BASE}/downloads/texas-holdem-gym-windows.exe`,
  mac: `${BASE}/downloads/texas-holdem-gym-mac.dmg`,
} as const;
