import { Resend } from "resend";

function getResend(): Resend {
  const key = process.env.RESEND_API_KEY;
  if (!key) throw new Error("RESEND_API_KEY is not set");
  return new Resend(key);
}

let _resend: Resend | null = null;
function resend(): Resend {
  if (!_resend) _resend = getResend();
  return _resend;
}

const FROM_EMAIL = process.env.FROM_EMAIL || "noreply@texasholdemgym.com";
const SUPPORT_EMAIL = process.env.SUPPORT_EMAIL || "support@texasholdemgym.com";

const DOWNLOAD_BASE = process.env.NEXT_PUBLIC_DOWNLOAD_BASE_URL || "https://downloads.texasholdemgym.com";
const SITE_URL = (process.env.NEXT_PUBLIC_SITE_URL || "https://texasholdemgym.com").replace(/\/$/, "");

export async function sendDownloadEmail(to: string): Promise<void> {
  const windowsUrl = `${DOWNLOAD_BASE}/downloads/texas-holdem-gym-windows.exe`;
  const macUrl = `${DOWNLOAD_BASE}/downloads/texas-holdem-gym-mac.dmg`;

  const { error } = await resend().emails.send({
    from: `Texas Hold'em Gym <${FROM_EMAIL}>`,
    to,
    subject: "Your Texas Hold'em Gym Download",
    html: buildEmailHtml({ windowsUrl, macUrl }),
    text: buildEmailText({ windowsUrl, macUrl }),
  });

  if (error) {
    console.error("[Resend] Failed to send email:", error);
    throw new Error(`Email send failed: ${error.message}`);
  }
}

interface DownloadLinks {
  windowsUrl: string;
  macUrl: string;
}

function buildEmailHtml({ windowsUrl, macUrl }: DownloadLinks): string {
  const winIcon = `${SITE_URL}/icons/windows.svg`;
  const macIcon = `${SITE_URL}/icons/macos.svg`;
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Your Texas Hold'em Gym Download</title>
</head>
<body style="background:#0b090a;color:#f2ebe4;font-family:system-ui,sans-serif;margin:0;padding:0;">
  <div style="max-width:600px;margin:0 auto;padding:40px 24px;">
    <div style="text-align:center;margin-bottom:32px;">
      <h1 style="color:#b89a52;font-size:28px;margin:0 0 8px;">Texas Hold'em Gym</h1>
      <p style="color:#7a7068;font-size:14px;margin:0;">Your purchase is confirmed</p>
    </div>

    <div style="background:#161218;border:1px solid #3d3028;border-radius:12px;padding:32px;margin-bottom:24px;">
      <h2 style="color:#f2ebe4;font-size:20px;margin:0 0 16px;">Thank you for your purchase!</h2>
      <p style="color:#a89890;line-height:1.6;margin:0 0 24px;">
        You're all set to start improving your poker game. Download the app for <strong style="color:#f2ebe4;">Windows</strong> or <strong style="color:#f2ebe4;">macOS</strong> below.
      </p>

      <div style="margin-bottom:24px;">
        <a href="${windowsUrl}" style="display:block;background:#b89a52;color:#0b090a;text-decoration:none;padding:14px 24px;border-radius:8px;text-align:center;font-weight:bold;font-size:15px;margin-bottom:12px;">
          <img src="${winIcon}" width="18" height="18" alt="" style="vertical-align:middle;margin-right:8px;" />
          Download for Windows (.exe)
        </a>
        <a href="${macUrl}" style="display:block;background:#b89a52;color:#0b090a;text-decoration:none;padding:14px 24px;border-radius:8px;text-align:center;font-weight:bold;font-size:15px;">
          <img src="${macIcon}" width="18" height="18" alt="" style="vertical-align:middle;margin-right:8px;" />
          Download for macOS (.dmg)
        </a>
      </div>
    </div>

    <div style="background:#161218;border:1px solid #3d3028;border-radius:12px;padding:24px;margin-bottom:24px;">
      <h3 style="color:#b89a52;font-size:16px;margin:0 0 12px;">Installation</h3>
      <p style="color:#a89890;line-height:1.7;margin:0 0 8px;"><img src="${winIcon}" width="14" height="14" alt="" style="vertical-align:middle;margin-right:6px;" /><strong style="color:#f2ebe4;">Windows:</strong> Run the .exe installer and follow the prompts.</p>
      <p style="color:#a89890;line-height:1.7;margin:0;"><img src="${macIcon}" width="14" height="14" alt="" style="vertical-align:middle;margin-right:6px;" /><strong style="color:#f2ebe4;">macOS:</strong> Open the .dmg, drag Texas Hold'em Gym to Applications.</p>
    </div>

    <div style="text-align:center;color:#7a7068;font-size:13px;">
      <p>Need help? Email us at <a href="mailto:${SUPPORT_EMAIL}" style="color:#b89a52;">${SUPPORT_EMAIL}</a></p>
      <p>These download links do not expire.</p>
    </div>
  </div>
</body>
</html>`;
}

function buildEmailText({ windowsUrl, macUrl }: DownloadLinks): string {
  return `Thank you for purchasing Texas Hold'em Gym!

Download links (Windows & macOS):

Windows: ${windowsUrl}
macOS: ${macUrl}

Installation:
- Windows: Run the .exe installer
- macOS: Open .dmg and drag to Applications

Need help? Email ${SUPPORT_EMAIL}
Download links do not expire.`;
}
