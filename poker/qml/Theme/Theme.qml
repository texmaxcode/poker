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

    /// Primary accent — muted brass (was brighter #d4af37; toned down for less glare on dark UI).
    readonly property color gold: "#b89a52"
    readonly property color goldMuted: "#8a6f38"
    readonly property color fire: "#ff6a1a"
    readonly property color fireDeep: "#c2410c"
    readonly property color ember: "#dc2626"
    readonly property color textPrimary: "#f2ebe4"
    readonly property color textSecondary: "#a89890"
    readonly property color textMuted: "#7a7068"

    /// Bundled Google Fonts — registered in `main.cpp` (`appFontFamily*` root-context strings).
    /// Merriweather — body copy, forms, labels (default app font).
    readonly property string fontFamilyUi: appFontFamily
    /// Rye — logo / panel & toolbar titles.
    readonly property string fontFamilyDisplay: appFontFamilyDisplay
    /// Holtwood One SC — `GameButton` and action chrome.
    readonly property string fontFamilyButton: appFontFamilyButton
    /// Roboto Mono — chips, stacks, pot, sliders, monospace fields.
    readonly property string fontFamilyMono: appFontFamilyMono

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
    readonly property color inputBg: "#222028"
    readonly property color inputBorder: "#4a4048"
    readonly property color accentBlue: "#7eb8e8"
    readonly property color hudActionLabel: "#8b93a8"
    readonly property color hudActionPanel: "#3a4a6a"
    readonly property color hudActionBright: "#d0e4ff"
    readonly property color insetDark: "#222"
    readonly property color dangerBg: "#4a2020"
    readonly property color dangerText: "#f5d0d0"
    readonly property color successGreen: "#1a6b45"
    readonly property color focusGold: "#a89248"
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

    /// Per-seat accents (names, setup tabs, stats, bankroll chart) — subdued metallics + burgundy + gunmetal
    /// to match the logo banner, chrome “GYM” type, and dumbbell steel (not neon primaries).
    readonly property var chartLineColors: [
        "#c6a86c",
        "#a07078",
        "#8b93a4",
        "#a8926a",
        "#6d8a7c",
        "#9e7a82"
    ]

    /// Text / accent color for seat `0`…`5` — matches `chartLineColors` and the bankroll chart legend.
    function colorForSeat(seat) {
        var c = chartLineColors
        if (seat === undefined || seat < 0 || seat >= c.length)
            return textPrimary
        return c[seat]
    }

    /// Scale form/lobby controls: slightly larger on small windows, slightly smaller on very large ones.
    function compactUiScale(shortSide) {
        var s = shortSide > 0 ? shortSide : 720
        return Math.min(1.2, Math.max(0.88, 720 / Math.max(s, 420)))
    }

    /// Hex strings for Canvas2D (`fillStyle` / `strokeStyle`).
    readonly property string chartPlotFill: "#141016"
    readonly property string chartGridLine: "#2a3040"
    readonly property string chartAxisText: "#6a7080"

    readonly property color profitUp: "#6fdc8c"
    readonly property color profitDown: "#ff8a8a"

    readonly property color sectionTitle: gold
    readonly property real bodyLineHeight: 1.35
    readonly property int formLabelPx: 14
    readonly property int formRowSpacing: 10
    readonly property int formColGap: 12
    readonly property int panelGap: 16

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
    /// Flop trainer: community cards match table scale so pot + board + seat fit without overlap.
    readonly property int trainerFlopBoardCardWidth: 100
    readonly property int trainerFlopBoardCardHeight: 148
    /// Gap between drill cards and between HUD action rows — matches `GameControls` action spacing (12).
    readonly property int trainerDrillHudSpacing: 12
    /// Nudge hero seat horizontally from panel center (negative = left) so HUD sits clearly to the side.
    readonly property int trainerDrillSeatCenterOffset: -44

    /// Typography for training copy — sized for Merriweather (wider serif; Oswald was condensed so read smaller).
    readonly property int trainerPageHeadlinePt: 19
    readonly property int trainerSectionPx: 16
    readonly property int trainerBodyPx: 14
    readonly property int trainerCaptionPx: 14
    readonly property int trainerMetricLabelPx: 12
    readonly property int trainerMetricValuePx: 20
    readonly property int trainerToolButtonPx: 14
    readonly property int trainerButtonLabelPx: 15
    readonly property int trainerColumnSpacing: 14
    readonly property int trainerPanelPadding: 14
    readonly property int trainerPanelRadius: 10
    /// Drill panel: min / max / fallback height — table-aligned layout (pot/board top, seat bottom).
    readonly property int trainerDrillPanelMinH: 600
    readonly property int trainerDrillPanelMaxH: 760
    readonly property int trainerDrillPanelFallbackH: 660
    readonly property real trainerDrillPanelViewportFrac: 0.58

    /// Picks a drill panel height from the scroll viewport so short windows are not forced to 600px+.
    function trainerDrillPanelHeight(availableScrollHeight) {
        var h = availableScrollHeight
        if (h <= 0)
            return trainerDrillPanelFallbackH
        var want = Math.round(h * trainerDrillPanelViewportFrac)
        var minH = Math.min(trainerDrillPanelMinH, Math.max(260, h - 220))
        var maxH = Math.min(trainerDrillPanelMaxH, Math.max(minH, h - 28))
        return Math.max(minH, Math.min(maxH, want))
    }
    /// Embedded `GameControls` must fit FOLD/CALL/RAISE (or CHECK / bet / bet) in one row (~300px + margins).
    readonly property int trainerEmbeddedHudMinWidth: 340
    /// Win-line banner: mini cards beside one-line result text (`GameControls` embedded HUD).
    readonly property int resultBannerCardW: 40
    readonly property int resultBannerCardH: 58
    readonly property int trainerSpinBoxWidth: 140

    /// Lobby / setup / stats / solver / training scroll pages (not the in-game table/HUD).
    readonly property int uiPagePadding: 15
    /// Space between the toolbar (or window top on lobby) and the first line of scroll content.
    readonly property int uiScrollViewTopPadding: 18
    /// GroupBox and grouped panels outside the poker table (matches training panel padding).
    readonly property int uiGroupedPanelPadding: 14
    /// Vertical spacing inside GroupBox ColumnLayouts (setup, stats, solver).
    readonly property int uiGroupInnerSpacing: 11
    /// Application-wide UI (lobby, stats, setup, solver, table, HUD).
    readonly property int uiBasePt: 13
    readonly property int uiToolBarTitlePt: 18
    /// Lobby chrome chip label + icon (smaller than centered page title).
    readonly property int uiToolBarChromePt: 13
    readonly property int uiBodyPx: 13
    readonly property int uiSmallPx: 12
    readonly property int uiMicroPx: 11
    readonly property int uiMonoPx: 12
    /// Lobby framed panel heading (“What would you like to do?”).
    readonly property int uiLobbyPanelTitlePx: 18
    /// Nav tiles: title + sub use `pixelSize`; two-line caps; fixed block heights keep every tile aligned.
    readonly property int uiLobbyNavTileTitlePx: 14
    readonly property int uiLobbyNavSubPx: 13
    readonly property real uiLobbyNavTileTitleLineHeight: 1.2
    readonly property real uiLobbyNavTileSubLineHeight: 1.2
    /// Fixed content height for title block (two lines at `titlePx` × line height).
    readonly property int uiLobbyNavTitleBlockH: 36
    readonly property int uiLobbyNavSubBlockH: 30
    readonly property int uiLobbyNavTilePadding: 17
    /// Space between icon / title / sub stacks inside a tile.
    readonly property int uiLobbyNavTileStackSpacing: 8
    /// Gap between lobby nav tiles (lobby nav row).
    readonly property int uiLobbyNavRowSpacing: 20
    readonly property int uiLobbyNavTileMinHeight: 168
    readonly property int uiLobbyNavIconPx: 40
    readonly property int uiPotMainPt: 22
    readonly property int uiPotSepPt: 18
    readonly property int uiPotCallPt: 18
    readonly property int uiSeatFoldPt: 12
    readonly property int uiSeatStreetPt: 11
    readonly property int uiSeatNamePt: 12
    readonly property int uiSeatPosPt: 13
    readonly property int uiStackPt: 18
    readonly property int uiHudButtonPt: 11
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
    /// `SizingPresetBar`: gap between Min / ⅓ / … chips (table + training `GameControls`).
    readonly property int sizingPresetBarSpacing: 10
    /// Tap height for preset chips — room for label + vertical padding.
    readonly property int sizingPresetButtonHeight: 40
    /// Inset inside the grey raise panel (slider + presets) above/below and left/right.
    readonly property int sizingRaisePanelPadV: 14
    readonly property int sizingRaisePanelPadH: 12
    /// Space between the amount slider row and the preset button row.
    readonly property int sizingRaiseSliderToPresetGap: 12

    /// 13×13 range editor: heatmap and composite layers (gold / fire / burgundy — matches logo banner & type).
    readonly property color rangeHeatLo: panel
    readonly property color rangeHeatHi: gold
    /// Muted heat top — blends into `panel` for a quieter single-layer heatmap.
    readonly property color rangeHeatHiSubdued: Qt.tint(panel, Qt.alpha(gold, 0.55))
    /// Call layer — warm gold (passive / continue).
    readonly property color rangeLayerCall: "#d4b84a"
    /// Raise layer — fire orange (aggression).
    readonly property color rangeLayerRaise: fire
    /// Open layer — burgundy rose (distinct from raise, readable on dark felt).
    readonly property color rangeLayerOpen: "#a85868"
    /// Composite strips: tinted into `panel` so the grid reads quieter than full accent fills.
    readonly property color rangeLayerCallSubdued: Qt.tint(panel, Qt.alpha(rangeLayerCall, 0.56))
    readonly property color rangeLayerRaiseSubdued: Qt.tint(panel, Qt.alpha(rangeLayerRaise, 0.52))
    readonly property color rangeLayerOpenSubdued: Qt.tint(panel, Qt.alpha(rangeLayerOpen, 0.54))
    /// Region underlays: upper triangle = suited, lower = offsuit, diagonal = pairs.
    readonly property color rangeGridPairTint: Qt.rgba(1, 1, 1, 0.08)
    readonly property color rangeGridSuitedTint: Qt.rgba(0.42, 0.58, 0.75, 0.16)
    readonly property color rangeGridOffsuitTint: Qt.rgba(0.68, 0.52, 0.42, 0.14)

    /// Text color for labels on accent-colored buttons (gold, green, etc.).
    readonly property color onAccentText: "#ffffff"
}
