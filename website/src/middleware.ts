import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { jwtVerify } from "jose";

const COOKIE_NAME = "admin_session";

function getSecret(): Uint8Array | null {
  const s = process.env.ADMIN_JWT_SECRET || process.env.ADMIN_SECRET;
  if (!s || s.length < 16) return null;
  return new TextEncoder().encode(s);
}

async function isValidSession(token: string | undefined): Promise<boolean> {
  const secret = getSecret();
  if (!secret || !token) return false;
  try {
    const { payload } = await jwtVerify(token, secret);
    return payload.role === "admin";
  } catch {
    return false;
  }
}

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (!pathname.startsWith("/admin")) {
    return NextResponse.next();
  }

  if (pathname === "/admin/login") {
    const ok = await isValidSession(request.cookies.get(COOKIE_NAME)?.value);
    if (ok) {
      return NextResponse.redirect(new URL("/admin", request.url));
    }
    return NextResponse.next();
  }

  const ok = await isValidSession(request.cookies.get(COOKIE_NAME)?.value);
  if (!ok) {
    const login = new URL("/admin/login", request.url);
    login.searchParams.set("next", pathname);
    return NextResponse.redirect(login);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/admin", "/admin/:path*"],
};
