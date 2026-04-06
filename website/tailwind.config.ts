import type { Config } from "tailwindcss";

export default {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      // ── Fonts — matches app's bundled Google Fonts ────────────────────────
      fontFamily: {
        // Rye — logo/panel/toolbar titles (app: fontFamilyDisplay)
        display: ["var(--font-rye)", "Georgia", "serif"],
        // Merriweather — body copy, labels, forms (app: fontFamilyUi)
        body: ["var(--font-merriweather)", "Georgia", "serif"],
        // Holtwood One SC — buttons/action chrome (app: fontFamilyButton)
        button: ["var(--font-holtwood)", "Georgia", "serif"],
        // Roboto Mono — numbers, chips, stacks (app: fontFamilyMono)
        mono: ["var(--font-mono)", "ui-monospace", "monospace"],
      },

      // ── Palette — direct match to Theme.qml ──────────────────────────────
      colors: {
        gold: {
          DEFAULT: "#b89a52",   // Theme.gold
          muted:   "#8a6f38",   // Theme.goldMuted
          bright:  "#d4b84a",   // Theme.rangeLayerCall (brighter gold)
        },
        fire: {
          DEFAULT: "#ff6a1a",   // Theme.fire
          deep:    "#c2410c",   // Theme.fireDeep
        },
        poker: {
          bg:        "#0b090a", // Theme.bgWindow
          panel:     "#161218", // Theme.panel
          elevated:  "#1c1820", // Theme.panelElevated
          border:    "#3d3028", // Theme.panelBorder
          chrome:    "#6b5030", // Theme.chromeLine
          header:    "#141016", // Theme.headerBg
          headerRule:"#5c4020", // Theme.headerRule
          input:     "#222028", // Theme.inputBg
          inputBorder:"#4a4048",// Theme.inputBorder
        },
        felt: {
          hi:     "#1a4538",    // Theme.feltHighlight
          mid:    "#123028",    // Theme.feltMid
          shadow: "#081810",    // Theme.feltShadow
        },
        text: {
          primary:   "#f2ebe4", // Theme.textPrimary
          secondary: "#c4b8b0", // raised from #a89890 for WCAG contrast
          muted:     "#9a8e85", // raised from #7a7068 for readability
        },
      },

      backgroundImage: {
        "hero-gradient": "radial-gradient(ellipse at top, #16100e 0%, #0b090a 55%)",
        "card-gradient":  "linear-gradient(135deg, #1c1820 0%, #161218 100%)",
        "gold-gradient":  "linear-gradient(135deg, #d4b84a 0%, #b89a52 50%, #8a6f38 100%)",
        "header-rule":    "linear-gradient(90deg, transparent, #5c4020, transparent)",
      },

      boxShadow: {
        gold:    "0 0 30px rgba(184,154,82,0.3)",
        "gold-lg":"0 0 60px rgba(184,154,82,0.2)",
        card:    "0 8px 32px rgba(0,0,0,0.6)",
        panel:   "inset 0 1px 0 rgba(184,154,82,0.08)",
      },

      animation: {
        "glow-pulse": "glow-pulse 3s ease-in-out infinite",
      },
      keyframes: {
        "glow-pulse": {
          "0%, 100%": { boxShadow: "0 0 20px rgba(184,154,82,0.3)" },
          "50%":       { boxShadow: "0 0 50px rgba(184,154,82,0.6)" },
        },
      },
    },
  },
  plugins: [],
} satisfies Config;
