import QtQuick
import QtQuick.Controls
import Theme 1.0

/// Shared Min / ⅓ / ½ / ⅔ / Pot / All chips for raise (facing) vs open-raise sliders.
Row {
    id: root
    spacing: 5

    required property var hud
    required property Slider slider
    /// `"raise"` = facing a raise; `"open"` = first raise on a street.
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

    function applyPotFrac(num, den) {
        if (root.flavor === "raise")
            applyRaiseTotal(hud.facingNeedChips + Math.floor(hud.facingPotAmount * num / den))
        else
            applyOpenRaise(Math.floor(hud.facingPotAmount * num / den))
        if (root.afterPreset)
            root.afterPreset()
    }

    function runPreset(kind) {
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
                w: 40,
                kind: "min"
            },
            {
                label: qsTr("⅓"),
                w: 34,
                kind: "third"
            },
            {
                label: qsTr("½"),
                w: 34,
                kind: "half"
            },
            {
                label: qsTr("⅔"),
                w: 34,
                kind: "twothirds"
            },
            {
                label: qsTr("Pot"),
                w: 40,
                kind: "pot"
            },
            {
                label: qsTr("All"),
                w: 40,
                kind: "all"
            }
        ]

        delegate: Rectangle {
            required property var modelData
            width: modelData.w
            height: 28
            radius: 6
            color: Theme.hudActionPanel

            Text {
                anchors.centerIn: parent
                text: modelData.label
                color: Theme.textPrimary
                font.pointSize: (modelData.kind === "min" || modelData.kind === "pot" || modelData.kind === "all") ? 9 : 10
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.runPreset(modelData.kind)
                onEntered: parent.opacity = 0.88
                onExited: parent.opacity = 1
                onPressed: parent.opacity = 0.72
                onReleased: parent.opacity = containsMouse ? 0.88 : 1
            }
        }
    }
}
