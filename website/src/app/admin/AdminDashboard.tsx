"use client";

import { useCallback, useEffect, useState } from "react";

type Stats = {
  periodDays: number;
  totals: { pageViews: number; clicks: number; allEvents: number };
  topClicks: { name: string; count: number }[];
  topPaths: { path: string; count: number }[];
  dailyPageViews: { day: string; count: number }[];
  purchases: { count: number; revenueCents: number };
  recentSample: {
    id: string;
    type: string;
    name: string;
    path: string;
    referrer: string | null;
    ip: string | null;
    createdAt: string;
  }[];
};

type PurchaseRow = {
  id: string;
  email: string;
  stripeSessionId: string;
  stripePaymentIntentId: string | null;
  amount: number;
  currency: string;
  emailSent: boolean;
  refundedAt: string | null;
  stripeRefundId: string | null;
  createdAt: string;
};

type StripeCfg = {
  mode: string;
  stripeSecretKey: string;
  webhookSecretConfigured: boolean;
  webhookEndpointUrl: string;
  dashboardUrl: string;
  env: Record<string, boolean | string>;
  notes: string[];
};

type Tab = "overview" | "analytics" | "purchases" | "stripe";

export default function AdminDashboard() {
  const [tab, setTab] = useState<Tab>("overview");
  const [stats, setStats] = useState<Stats | null>(null);
  const [purchases, setPurchases] = useState<PurchaseRow[]>([]);
  const [stripeCfg, setStripeCfg] = useState<StripeCfg | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [refundingId, setRefundingId] = useState<string | null>(null);
  const [refundMsg, setRefundMsg] = useState("");

  const load = useCallback(async () => {
    setErr("");
    setLoading(true);
    try {
      const [sRes, pRes, cRes] = await Promise.all([
        fetch("/api/admin/stats"),
        fetch("/api/admin/purchases"),
        fetch("/api/admin/stripe-config"),
      ]);
      if (sRes.status === 401) {
        window.location.href = "/admin/login";
        return;
      }
      if (!sRes.ok) throw new Error("Failed to load stats");
      setStats(await sRes.json());
      if (pRes.ok) {
        const p = await pRes.json();
        setPurchases(p.purchases ?? []);
      }
      if (cRes.ok) {
        setStripeCfg(await cRes.json());
      }
    } catch (e) {
      setErr(e instanceof Error ? e.message : "Error");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function logout() {
    await fetch("/api/admin/logout", { method: "POST" });
    window.location.href = "/admin/login";
  }

  async function refund(id: string) {
    if (!confirm("Issue a full refund in Stripe for this purchase?")) return;
    setRefundingId(id);
    setRefundMsg("");
    try {
      const res = await fetch("/api/admin/refund", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ purchaseId: id }),
      });
      const data = await res.json();
      if (!res.ok) {
        setRefundMsg(data.error || "Refund failed");
        setRefundingId(null);
        return;
      }
      setRefundMsg(`Refunded: ${data.refundId}`);
      await load();
    } catch {
      setRefundMsg("Network error");
    } finally {
      setRefundingId(null);
    }
  }

  return (
    <div className="max-w-6xl mx-auto px-4 py-8">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
        <div>
          <h1 className="font-rye text-3xl text-gold-gradient">Admin</h1>
          <p className="text-[#9a8e85] text-sm">Analytics, purchases, refunds & Stripe</p>
        </div>
        <button
          type="button"
          onClick={() => void logout()}
          className="self-start px-4 py-2 rounded-lg border border-[#3d3028] text-sm text-[#c4b8b0] hover:border-gold/40 hover:text-gold"
        >
          Sign out
        </button>
      </div>

      <div className="flex flex-wrap gap-2 mb-8 border-b border-[#3d3028] pb-2">
        {(
          [
            ["overview", "Overview"],
            ["analytics", "Visits & clicks"],
            ["purchases", "Purchases & refunds"],
            ["stripe", "Stripe"],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            type="button"
            onClick={() => setTab(id)}
            className={`px-4 py-2 rounded-t-lg text-sm font-medium transition-colors ${
              tab === id ? "bg-[#161218] text-gold border border-b-0 border-[#3d3028]" : "text-[#9a8e85] hover:text-[#c4b8b0]"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {loading ? (
        <p className="text-[#9a8e85]">Loading…</p>
      ) : err ? (
        <p className="text-red-400">{err}</p>
      ) : (
        <>
          {tab === "overview" && stats && (
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
              <div className="rounded-xl border border-[#3d3028] bg-[#161218] p-5">
                <div className="text-[#9a8e85] text-xs uppercase tracking-wider mb-1">Page views (30d)</div>
                <div className="text-3xl font-semibold text-[#f2ebe4]">{stats.totals.pageViews}</div>
              </div>
              <div className="rounded-xl border border-[#3d3028] bg-[#161218] p-5">
                <div className="text-[#9a8e85] text-xs uppercase tracking-wider mb-1">Tracked clicks (30d)</div>
                <div className="text-3xl font-semibold text-[#f2ebe4]">{stats.totals.clicks}</div>
              </div>
              <div className="rounded-xl border border-[#3d3028] bg-[#161218] p-5">
                <div className="text-[#9a8e85] text-xs uppercase tracking-wider mb-1">Revenue (non-refunded)</div>
                <div className="text-3xl font-semibold text-gold">
                  ${((stats.purchases.revenueCents || 0) / 100).toFixed(2)}
                </div>
                <div className="text-xs text-[#9a8e85] mt-1">{stats.purchases.count} purchases</div>
              </div>
            </div>
          )}

          {tab === "analytics" && stats && (
            <div className="space-y-8">
              <div>
                <h2 className="font-rye text-lg text-gold mb-3">Top clicks (30d)</h2>
                <div className="rounded-xl border border-[#3d3028] overflow-hidden">
                  <table className="w-full text-sm">
                    <thead className="bg-[#141016] text-[#9a8e85] text-left">
                      <tr>
                        <th className="px-4 py-2">Element / action</th>
                        <th className="px-4 py-2 w-24">Count</th>
                      </tr>
                    </thead>
                    <tbody>
                      {stats.topClicks.length === 0 ? (
                        <tr>
                          <td colSpan={2} className="px-4 py-6 text-[#9a8e85]">
                            No clicks yet. Add{" "}
                            <code className="text-gold/80">data-track</code> on buttons/links.
                          </td>
                        </tr>
                      ) : (
                        stats.topClicks.map((r) => (
                          <tr key={r.name} className="border-t border-[#2a2428]">
                            <td className="px-4 py-2 font-mono text-xs text-[#c4b8b0]">{r.name}</td>
                            <td className="px-4 py-2 text-[#f2ebe4]">{r.count}</td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
              <div>
                <h2 className="font-rye text-lg text-gold mb-3">Top pages (30d)</h2>
                <div className="rounded-xl border border-[#3d3028] overflow-hidden">
                  <table className="w-full text-sm">
                    <thead className="bg-[#141016] text-[#9a8e85] text-left">
                      <tr>
                        <th className="px-4 py-2">Path</th>
                        <th className="px-4 py-2 w-24">Views</th>
                      </tr>
                    </thead>
                    <tbody>
                      {stats.topPaths.map((r) => (
                        <tr key={r.path} className="border-t border-[#2a2428]">
                          <td className="px-4 py-2 font-mono text-xs text-[#c4b8b0]">{r.path}</td>
                          <td className="px-4 py-2 text-[#f2ebe4]">{r.count}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
              <div>
                <h2 className="font-rye text-lg text-gold mb-3">Daily page views (14d)</h2>
                <div className="flex flex-wrap gap-2">
                  {stats.dailyPageViews.map((d) => (
                    <div key={d.day} className="px-3 py-2 rounded-lg bg-[#161218] border border-[#3d3028] text-xs">
                      <span className="text-[#9a8e85]">{d.day}</span>
                      <span className="ml-2 text-[#f2ebe4] font-semibold">{d.count}</span>
                    </div>
                  ))}
                </div>
              </div>
              <div>
                <h2 className="font-rye text-lg text-gold mb-3">Recent events (sample)</h2>
                <div className="rounded-xl border border-[#3d3028] overflow-x-auto">
                  <table className="w-full text-xs min-w-[640px]">
                    <thead className="bg-[#141016] text-[#9a8e85] text-left">
                      <tr>
                        <th className="px-3 py-2">Time</th>
                        <th className="px-3 py-2">Type</th>
                        <th className="px-3 py-2">Name</th>
                        <th className="px-3 py-2">Path</th>
                        <th className="px-3 py-2">IP</th>
                      </tr>
                    </thead>
                    <tbody>
                      {stats.recentSample.map((r) => (
                        <tr key={r.id} className="border-t border-[#2a2428]">
                          <td className="px-3 py-1.5 text-[#9a8e85] whitespace-nowrap">
                            {new Date(r.createdAt).toLocaleString()}
                          </td>
                          <td className="px-3 py-1.5 text-[#c4b8b0]">{r.type}</td>
                          <td className="px-3 py-1.5 font-mono text-[#c4b8b0] max-w-[200px] truncate">{r.name}</td>
                          <td className="px-3 py-1.5 font-mono text-[#9a8e85]">{r.path}</td>
                          <td className="px-3 py-1.5 text-[#9a8e85]">{r.ip || "—"}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {tab === "purchases" && (
            <div>
              {refundMsg ? (
                <p className={`mb-4 text-sm ${refundMsg.startsWith("Refunded") ? "text-green-400" : "text-red-400"}`}>
                  {refundMsg}
                </p>
              ) : null}
              <div className="rounded-xl border border-[#3d3028] overflow-x-auto">
                <table className="w-full text-sm min-w-[800px]">
                  <thead className="bg-[#141016] text-[#9a8e85] text-left text-xs">
                    <tr>
                      <th className="px-3 py-2">Date</th>
                      <th className="px-3 py-2">Email</th>
                      <th className="px-3 py-2">Amount</th>
                      <th className="px-3 py-2">Email sent</th>
                      <th className="px-3 py-2">Refund</th>
                      <th className="px-3 py-2" />
                    </tr>
                  </thead>
                  <tbody>
                    {purchases.map((p) => (
                      <tr key={p.id} className="border-t border-[#2a2428]">
                        <td className="px-3 py-2 text-[#9a8e85] whitespace-nowrap">
                          {new Date(p.createdAt).toLocaleDateString()}
                        </td>
                        <td className="px-3 py-2 text-[#c4b8b0] max-w-[180px] truncate">{p.email}</td>
                        <td className="px-3 py-2 text-[#f2ebe4]">
                          ${(p.amount / 100).toFixed(2)} {p.currency.toUpperCase()}
                        </td>
                        <td className="px-3 py-2">{p.emailSent ? "✓" : "—"}</td>
                        <td className="px-3 py-2 text-xs text-[#9a8e85]">
                          {p.refundedAt ? (
                            <span className="text-amber-400/90">Refunded {p.stripeRefundId?.slice(0, 12)}…</span>
                          ) : (
                            "—"
                          )}
                        </td>
                        <td className="px-3 py-2 text-right">
                          {!p.refundedAt ? (
                            <button
                              type="button"
                              disabled={refundingId === p.id}
                              onClick={() => void refund(p.id)}
                              className="text-xs px-3 py-1 rounded border border-red-900/60 text-red-300 hover:bg-red-950/40 disabled:opacity-50"
                            >
                              {refundingId === p.id ? "…" : "Refund"}
                            </button>
                          ) : null}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {tab === "stripe" && stripeCfg && (
            <div className="space-y-6 max-w-2xl">
              <div className="rounded-xl border border-[#3d3028] bg-[#161218] p-6 space-y-3 text-sm">
                <div className="flex justify-between gap-4">
                  <span className="text-[#9a8e85]">Mode</span>
                  <span className="text-[#f2ebe4] font-mono">{stripeCfg.mode}</span>
                </div>
                <div className="flex justify-between gap-4">
                  <span className="text-[#9a8e85]">Secret key</span>
                  <span className="text-[#c4b8b0] font-mono text-xs">{stripeCfg.stripeSecretKey}</span>
                </div>
                <div className="flex justify-between gap-4">
                  <span className="text-[#9a8e85]">Webhook signing secret</span>
                  <span className="text-[#c4b8b0]">{stripeCfg.webhookSecretConfigured ? "Configured" : "Not set"}</span>
                </div>
                <div className="pt-2 border-t border-[#2a2428]">
                  <div className="text-[#9a8e85] text-xs mb-1">Webhook URL (Stripe Dashboard)</div>
                  <code className="text-xs text-gold/90 break-all">{stripeCfg.webhookEndpointUrl}</code>
                </div>
                <div>
                  <a
                    href={stripeCfg.dashboardUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-gold hover:text-gold-bright text-sm underline"
                  >
                    Open Stripe Dashboard →
                  </a>
                </div>
              </div>
              <ul className="text-[#9a8e85] text-xs space-y-1 list-disc list-inside">
                {stripeCfg.notes.map((n) => (
                  <li key={n}>{n}</li>
                ))}
              </ul>
              <div className="text-xs text-[#7a7068]">
                Change keys and webhook in your hosting provider&apos;s environment variables, then redeploy.
              </div>
            </div>
          )}
        </>
      )}

      <p className="mt-10 text-center text-[#5c5048] text-xs">
        Analytics excludes <code className="text-[#7a7068]">/admin</code> routes. Do not share admin credentials.
      </p>
    </div>
  );
}
