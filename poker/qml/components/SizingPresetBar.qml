import QtQuick
import QtQuick.Controls
import Theme 1.0

/// Shared Min / ⅓ / ½ / ⅔ / Pot / All chips for raise (facing) vs open-raise sliders.
Row {
    id: root
    spacing: Theme.sizingPresetBarSpacing

    required property var hud
    required property Slider slider
    /// `"raise"` = facing a raise; `"open"` = first raise on a street; `"bb"` = BB preflop raise (chips to add).
    property string flavor: "raise"
    /// Called after a preset updates the slider (e.g. submit bet/raise in the parent HUD).
    property var afterPreset: null

    function clampToSlider(v) {
        var lo = slider.from
        var hi = slider.to
        return Math.min(Math.max(v, lo), hi)
    }

    function applyRaiseTotal(v) {
        v = Math.max(v, hud.facingMinRaiseChips)
        slider.value = clampToSlider(v)
    }

    function applyOpenRaise(v) {
        v = Math.max(v, hud.openRaiseMinChips)
        slider.value = clampToSlider(v)
    }

    function applyBbRaise(v) {
        v = Math.max(v, hud.bbPreflopMinChips)
        slider.value = clampToSlider(v)
    }

    function applyPotFrac(num, den) {
        if (root.flavor === "raise")
            applyRaiseTotal(hud.facingNeedChips + Math.floor(hud.facingPotAmount * num / den))
        else
            applyOpenRaise(Math.floor(hud.facingPotAmount * num / den))
        if (root.afterPreset)
            root.afterPreset()
    }

    function runPreset(kind) {
        if (root.flavor === "bb") {
            switch (kind) {
            case "min":
                applyBbRaise(hud.bbPreflopMinChips)
                break
            case "third":
                applyBbRaise(Math.floor(hud.facingPotAmount / 3))
                break
            case "half":
                applyBbRaise(Math.floor(hud.facingPotAmount / 2))
                break
            case "twothirds":
                applyBbRaise(Math.floor(hud.facingPotAmount * 2 / 3))
                break
            case "pot":
                applyBbRaise(Math.min(hud.bbPreflopMaxChips,
                        Math.max(hud.bbPreflopMinChips, hud.facingPotAmount)))
                break
            case "all":
                applyBbRaise(hud.bbPreflopMaxChips)
                break
            default:
                return
            }
            if (root.afterPreset)
                root.afterPreset()
            return
        }
        switch (kind) {
        case "min":
            if (root.flavor === "raise")
                applyRaiseTotal(hud.facingMinRaiseChips)
            else
                applyOpenRaise(hud.openRaiseMinChips)
            break
        case "third":
            applyPotFrac(1, 3)
            return
        case "half":
            applyPotFrac(1, 2)
            return
        case "twothirds":
            applyPotFrac(2, 3)
            return
        case "pot":
            if (root.flavor === "raise")
                applyRaiseTotal(hud.facingNeedChips + hud.facingPotAmount)
            else
                applyOpenRaise(Math.min(hud.facingPotAmount, slider.to))
            break
        case "all":
            if (root.flavor === "raise")
                applyRaiseTotal(slider.to)
            else
                applyOpenRaise(slider.to)
            break
        default:
            return
        }
        if (root.afterPreset)
            root.afterPreset()
    }

    Repeater {
        model: [
            {
                label: qsTr("Min"),
                w: 44,
                kind: "min"
            },
            {
                label: qsTr("⅓"),
                w: 38,
                kind: "third"
            },
            {
                label: qsTr("½"),
                w: 38,
                kind: "half"
            },
            {
                label: qsTr("⅔"),
                w: 38,
                kind: "twothirds"
            },
            {
                label: qsTr("Pot"),
                w: 44,
                kind: "pot"
            },
            {
                label: qsTr("All"),
                w: 44,
                kind: "all"
            }
        ]

        delegate: Item {
            required property var modelData
            width: modelData.w
            height: Theme.sizingPresetButtonHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 6
                color: Theme.hudActionPanel
                opacity: presetMa.pressed ? 0.72 : (presetMa.containsMouse ? 0.88 : 1)

                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: Theme.textPrimary
                    font.family: Theme.fontFamilyUi
                    font.pointSize: (modelData.kind === "min" || modelData.kind === "pot" || modelData.kind === "all") ? Theme.uiMicroPx : Theme.uiSizingPresetPt
                    font.bold: true
                }
            }

            MouseArea {
                id: presetMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.runPreset(modelData.kind)
            }
        }
    }
}
