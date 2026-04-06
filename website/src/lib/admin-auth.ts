import { SignJWT, jwtVerify } from "jose";

const COOKIE_NAME = "admin_session";

export function getAdminSecretBytes(): Uint8Array | null {
  const s = process.env.ADMIN_JWT_SECRET || process.env.ADMIN_SECRET;
  if (!s || s.length < 16) return null;
  return new TextEncoder().encode(s);
}

function getSecret(): Uint8Array {
  const b = getAdminSecretBytes();
  if (!b) {
    throw new Error("ADMIN_JWT_SECRET (or ADMIN_SECRET) must be set and at least 16 characters");
  }
  return b;
}

export async function createAdminToken(): Promise<string> {
  return new SignJWT({ role: "admin" })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("7d")
    .sign(getSecret());
}

export async function verifyAdminToken(token: string): Promise<boolean> {
  const secret = getAdminSecretBytes();
  if (!secret) return false;
  try {
    const { payload } = await jwtVerify(token, secret);
    return payload.role === "admin";
  } catch {
    return false;
  }
}

export { COOKIE_NAME };
