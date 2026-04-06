"use client";

import { useState, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const next = searchParams.get("next") || "/admin";
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await fetch("/api/admin/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ password }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        setError(typeof data.error === "string" ? data.error : "Login failed");
        setLoading(false);
        return;
      }
      router.push(next);
      router.refresh();
    } catch {
      setError("Network error");
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center px-4">
      <div className="w-full max-w-sm border border-[#3d3028] rounded-xl bg-[#161218] p-8 shadow-card">
        <h1 className="font-rye text-2xl text-gold-gradient mb-1 text-center">Admin</h1>
        <p className="text-[#9a8e85] text-sm text-center mb-6">Texas Hold&apos;em Gym</p>
        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <label htmlFor="pw" className="block text-xs text-[#9a8e85] mb-1.5">
              Password
            </label>
            <input
              id="pw"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-lg bg-[#222028] border border-[#4a4048] px-3 py-2.5 text-sm text-[#f2ebe4] focus:outline-none focus:ring-2 focus:ring-gold/40"
              required
            />
          </div>
          {error ? <p className="text-red-400 text-sm">{error}</p> : null}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-2.5 rounded-lg bg-gold text-poker-bg font-semibold text-sm hover:bg-gold-bright disabled:opacity-60"
          >
            {loading ? "Signing in…" : "Sign in"}
          </button>
        </form>
      </div>
    </div>
  );
}

export default function AdminLoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-[#9a8e85]">Loading…</div>}>
      <LoginForm />
    </Suspense>
  );
}
