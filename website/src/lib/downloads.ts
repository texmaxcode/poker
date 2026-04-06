const BASE = process.env.NEXT_PUBLIC_DOWNLOAD_BASE_URL || "https://downloads.texasholdemgym.com";

export const DOWNLOAD_LINKS = {
  windows: `${BASE}/downloads/texas-holdem-gym-windows.exe`,
  mac: `${BASE}/downloads/texas-holdem-gym-mac.dmg`,
  linux: `${BASE}/downloads/texas-holdem-gym-linux.AppImage`,
} as const;
