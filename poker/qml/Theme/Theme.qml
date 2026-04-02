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

    /// Bundled Oswald (registered in `main.cpp`); also exposed as root-context `appFontFamily`.
    readonly property string fontFamilyUi: appFontFamily

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

    /// Text / accent color for seat `0`…`5` — matches `chartLineColors` and the bankroll chart legend.
    function colorForSeat(seat) {
        var c = chartLineColors
        if (seat === undefined || seat < 0 || seat >= c.length)
            return textPrimary
        return c[seat]
    }

    /// Hex strings for Canvas2D (`fillStyle` / `strokeStyle`).
    readonly property string chartPlotFill: "#141016"
    readonly property string chartGridLine: "#2a3040"
    readonly property string chartAxisText: "#6a7080"

    readonly property color profitUp: "#6fdc8c"
    readonly property color profitDown: "#ff8a8a"

    /// Playing cards (~1 : 1.48 width:height). Pair width matches 204px seat inner (margins 4).
    readonly property int holeCardWidth: 96
    readonly property int holeCardHeight: 142
    readonly property int holeCardGap: 4
    readonly property int holePairTotalWidth: 2 * holeCardWidth + holeCardGap
    /// Board / default `Card` footprint — five across + spacing fits centered on typical table width.
    readonly property int boardCardWidth: 108
    readonly property int boardCardHeight: 160

    /// Training / drill screens: keep readable line length and controls off ultra-wide edges.
    readonly property int trainerContentMaxWidth: 920
    /// Drill cards (preflop / flop trainers) — larger than table `boardCard*` for study screens only.
    readonly property int trainerDrillCardWidth: 150
    readonly property int trainerDrillCardHeight: 222
    /// Flop trainer: community cards match table scale so pot + board + seat fit without overlap.
    readonly property int trainerFlopBoardCardWidth: 100
    readonly property int trainerFlopBoardCardHeight: 148
    /// Gap between drill cards and between `HudButton` rows — matches `GameControls` action spacing (12).
    readonly property int trainerDrillHudSpacing: 12
    /// Inset from drill area right edge for embedded HUD — space between centered seat and controls.
    readonly property int trainerHudSeatMargin: 22
    /// Nudge hero seat horizontally from panel center (negative = left) so HUD sits clearly to the side.
    readonly property int trainerDrillSeatCenterOffset: -44

    /// Typography for training copy (large for readability). Body = primary reading style (match TrainerHome intro).
    readonly property int trainerTitlePt: 26
    readonly property int trainerPageHeadlinePt: 22
    readonly property int trainerSectionPx: 20
    readonly property int trainerBodyPx: 17
    /// Kept for compatibility; same as `trainerBodyPx` so all trainer paragraphs match.
    readonly property int trainerBodyMutedPx: 17
    readonly property int trainerCaptionPx: 17
    readonly property int trainerStatusPx: 23
    /// Feedback / grade line after an answer (same px as status for consistency).
    readonly property int trainerResultPx: 23
    /// Fixed slot at top of preflop/flop drill cards — avoids layout jump when feedback length changes.
    readonly property int trainerExerciseStatusSlotHeight: 128
    readonly property int trainerMetricLabelPx: 15
    readonly property int trainerMetricValuePx: 24
    readonly property int trainerToolButtonPx: 17
    readonly property int trainerButtonLabelPx: 19
    readonly property int trainerGroupTitlePt: 15

    readonly property int trainerColumnSpacing: 14
    readonly property int trainerPanelPadding: 14
    readonly property int trainerPanelRadius: 10
    /// Drill panel: min / max / fallback height — table-aligned layout (pot/board top, seat bottom).
    readonly property int trainerDrillPanelMinH: 600
    readonly property int trainerDrillPanelMaxH: 760
    readonly property int trainerDrillPanelFallbackH: 660
    readonly property real trainerDrillPanelViewportFrac: 0.58
    /// Embedded `GameControls` must fit FOLD/CALL/RAISE (or CHECK / bet / bet) in one row (~300px + margins).
    readonly property int trainerEmbeddedHudMinWidth: 340
    /// Win-line banner: mini cards beside one-line result text (`GameControls` embedded HUD).
    readonly property int resultBannerCardW: 40
    readonly property int resultBannerCardH: 58
    readonly property int trainerButtonPadding: 14
    readonly property int trainerSpinBoxWidth: 140

    /// Lobby / setup / stats / solver / training scroll pages (not the in-game table/HUD).
    readonly property int uiPagePadding: 15
    readonly property int uiPageColumnSpacing: 11
    /// GroupBox and grouped panels outside the poker table (matches training panel padding).
    readonly property int uiGroupedPanelPadding: 14
    readonly property int uiGroupedPanelTopPadding: 30
    /// Vertical spacing inside GroupBox ColumnLayouts (setup, stats, solver).
    readonly property int uiGroupInnerSpacing: 11
    /// Extra gap between the GroupBox title bar and the first line of body content.
    readonly property int uiGroupBoxTitleBodyGap: 10

    /// Application-wide UI (lobby, stats, setup, solver, table, HUD).
    readonly property int uiBasePt: 13
    readonly property int uiToolBarTitlePt: 13
    readonly property int uiToolBarBackPt: 11
    readonly property int uiGroupTitlePt: 14
    readonly property int uiBodyPx: 14
    readonly property int uiSmallPx: 12
    readonly property int uiMicroPx: 11
    readonly property int uiMonoPx: 13
    readonly property int uiLobbyTitlePt: 19
    /// Nav tiles: title line (two lines max).
    readonly property int uiLobbyNavTileTitlePt: 15
    readonly property int uiLobbyNavSubPx: 15
    readonly property int uiLobbyNavTilePadding: 11
    readonly property int uiLobbyNavTileMinHeight: 124
    readonly property int uiLobbyNavIconPx: 28
    readonly property int uiPotMainPt: 22
    readonly property int uiPotSepPt: 18
    readonly property int uiPotCallPt: 18
    readonly property int uiPotSidePt: 12
    readonly property int uiSeatFoldPt: 12
    readonly property int uiSeatStreetPt: 11
    readonly property int uiSeatNamePt: 12
    readonly property int uiSeatPosPt: 12
    readonly property int uiStackPt: 18
    readonly property int uiHudButtonPt: 11
    readonly property int uiGameHudPx: 14
    readonly property int uiChartLegendPx: 12
    readonly property int uiChartCanvasPx: 12
    readonly property int uiRangeGridAxisPx: 14
    readonly property int uiRangeGridLegendPx: 13
    /// 13×13 cell size (axis labels use row/col header widths below).
    readonly property int uiRangeGridCellW: 40
    readonly property int uiRangeGridCellH: 32
    readonly property int uiRangeGridRowHeaderW: 28
    readonly property int uiRangeGridCornerW: 22
    readonly property int uiRangeGridCornerH: 24
    readonly property int uiSizingPresetPt: 11

    /// 13×13 range editor: heatmap and composite layers (gold / fire / burgundy — matches logo banner & type).
    readonly property color rangeHeatLo: panel
    readonly property color rangeHeatHi: gold
    /// Call layer — warm gold (passive / continue).
    readonly property color rangeLayerCall: "#d4b84a"
    /// Raise layer — fire orange (aggression).
    readonly property color rangeLayerRaise: fire
    /// Open / lead layer — burgundy rose (distinct from raise, readable on dark felt).
    readonly property color rangeLayerOpen: "#a85868"

    /// Text color for labels on accent-colored buttons (gold, green, etc.).
    readonly property color onAccentText: "#ffffff"
    /// Short UI transition (hover, border, scale).
    readonly property int animDurationShort: 120
}
