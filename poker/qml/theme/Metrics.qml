pragma Singleton
import QtQuick

/// Layout constants — window chrome, HUD geometry, radii. Targets 1280×900 and 1920×1080.
QtObject {
    readonly property int windowWidthDefault: 1400
    readonly property int windowHeightDefault: 900
    readonly property int windowMinWidth: 720
    readonly property int windowMinHeight: 560

    readonly property int toolbarHeight: 42
    readonly property int toolbarMarginH: 8
    readonly property int toolbarMarginV: 5

    /// HUD pill height — matches previous compact action buttons so layout stays stable.
    readonly property int hudButtonHeight: 38
    readonly property int chipButtonHeight: 28
    readonly property int formButtonMinWidth: 96

    readonly property int radiusHudPill: 6
    readonly property int radiusToolbarButton: 8

    readonly property int iconToolbar: 16
    /// Toolbar back / Lobby chrome `GameButton` — sized to the ~32px content area.
    readonly property int iconToolbarChrome: 22
}
