import { NextResponse } from "next/server";
import { createAdminToken, COOKIE_NAME, getAdminSecretBytes } from "@/lib/admin-auth";

export async function POST(req: Request) {
  const secretOk = getAdminSecretBytes();
  if (!secretOk) {
    return NextResponse.json(
      { error: "Admin auth is not configured (set ADMIN_JWT_SECRET and ADMIN_PASSWORD)" },
      { status: 503 }
    );
  }

  let password = "";
  try {
    const body = await req.json();
    password = typeof body.password === "string" ? body.password : "";
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const expected = process.env.ADMIN_PASSWORD;
  if (!expected || password !== expected) {
    return NextResponse.json({ error: "Invalid credentials" }, { status: 401 });
  }

  let token: string;
  try {
    token = await createAdminToken();
  } catch (e) {
    console.error("[admin/login]", e);
    return NextResponse.json({ error: "Server misconfiguration" }, { status: 500 });
  }

  const res = NextResponse.json({ ok: true });
  res.cookies.set(COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 7,
  });
  return res;
}
