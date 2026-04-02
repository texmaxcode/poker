pragma Singleton
import QtQuick

/// Texas Hold'em Gym — palette aligned with brand logo (charcoal stone, burgundy banner,
/// gold/chrome type, fire accents).
QtObject {
    readonly property color bgWindow: "#0b090a"
    readonly property color bgGradientTop: "#16100e"
    readonly property color bgGradientMid: "#0a0809"
    readonly property color bgGradientBottom: "#060508"

    readonly property color panel: "#161218"
    readonly property color panelElevated: "#1c1820"
    readonly property color panelBorder: "#3d3028"
    readonly property color panelBorderMuted: "#2a2428"
    readonly property color chromeLine: "#6b5030"
    readonly property color chromeLineGold: "#8a6028"

    readonly property color gold: "#d4af37"
    readonly property color goldMuted: "#9a7a30"
    readonly property color fire: "#ff6a1a"
    readonly property color fireDeep: "#c2410c"
    readonly property color ember: "#dc2626"
    readonly property color burgundy: "#4a1820"

    readonly property color textPrimary: "#f2ebe4"
    readonly property color textSecondary: "#a89890"
    readonly property color textMuted: "#7a7068"

    readonly property color headerBg: "#141016"
    readonly property color headerRule: "#5c4020"

    readonly property color feltHighlight: "#1a4538"
    readonly property color feltMid: "#123028"
    readonly property color feltShadow: "#081810"
    readonly property color feltBorder: "#0a2820"
    readonly property color railOuter: "#121018"
    readonly property color railBezel: "#1a1018"
    readonly property color railWood0: "#4a3228"
    readonly property color railWood1: "#2a1810"
    readonly property color railWood2: "#140c08"
    readonly property color railEdge: "#a06840"

    readonly property color hudBg0: "#2a1c14"
    readonly property color hudBg1: "#140e0a"
    readonly property color hudBorder: "#7a5020"
    readonly property color hudDivider: "#5a3a1888"
    readonly property color inputBg: "#222028"
    readonly property color inputBorder: "#4a4048"
    readonly property color accentBlue: "#7eb8e8"
    readonly property color hudActionLabel: "#8b93a8"
    readonly property color hudActionAccent: "#7ec8ff"
    readonly property color hudActionPanel: "#3a4a6a"
    readonly property color hudActionBright: "#d0e4ff"
    readonly property color insetDark: "#222"
    readonly property color dangerBg: "#4a2020"
    readonly property color dangerText: "#f5d0d0"
    readonly property color successGreen: "#1a6b45"
    readonly property color focusGold: "#c9a227"
    /// Seat street-action strip (Call / Raise / Check / All-in / Fold).
    readonly property color streetActionCall: "#e8d040"
    readonly property color streetActionRaise: "#4ade80"
    readonly property color streetActionAllIn: "#ef4444"
    readonly property color streetActionCheck: "#7eb8e8"
    readonly property color streetActionFold: "#a89890"

    readonly property color seatPanel: "#15151c"
    readonly property color seatStackTint: "#2a1f18"
    readonly property color seatBorderIdle: "#4a3a32"
    readonly property color seatBorderAct: "#ff8c42"
    readonly property color progressTrack: "#1e1e26"

    readonly property var chartLineColors: ["#e8b84a", "#ff7a3a", "#8ec8f0", "#c9a227", "#5cd090", "#ff6a8a"]

    /// Hex strings for Canvas2D (`fillStyle` / `strokeStyle`).
    readonly property string chartPlotFill: "#141016"
    readonly property string chartGridLine: "#2a3040"
    readonly property string chartAxisText: "#6a7080"

    readonly property color profitUp: "#6fdc8c"
    readonly property color profitDown: "#ff8a8a"
}
