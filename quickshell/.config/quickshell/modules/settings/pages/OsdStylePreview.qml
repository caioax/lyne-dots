pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import "../../../components/osd/"

// The OSD over the current wallpaper with the real style at 65% volume,
// scaled down to fit, where that style would sit (its saved position, or its
// first one) next to a strip standing for the bar
ClippingRectangle {
    id: root

    // OSD style: "pill", "vertical", "card" or "attached"
    property string value

    readonly property var styles: ({
            "pill": pillStyle,
            "vertical": verticalStyle,
            "card": cardStyle,
            "attached": attachedStyle
        })

    readonly property string position: OsdService.positionFor(value)
    readonly property bool barOnTop: !Config.barOnBottom
    readonly property bool docked: !Config.barIslands && !Config.barFloating
    readonly property bool attached: value === "attached"
    // Same rule as OsdOverlay: the side it sits on, "" when centered
    readonly property string edge: {
        const barEdge = barOnTop ? "top" : "bottom";
        if (attached)
            return position === "bar" ? barEdge : (barEdge === "top" ? "bottom" : "top");
        return position === "center" ? "" : position;
    }

    // Below the selected tile's check (TemplateTile: padding inside the tile,
    // fontSizeLarge + padding tall) plus a small gap. The bar strip is that
    // tall, so the check sits on the bar
    readonly property int checkClearance: Config.padding * 2 + Config.fontSizeLarge + Math.round(Config.padding / 2)
    readonly property real gap: Config.spacing
    // Screen area outside the bar strip
    readonly property real areaTop: barOnTop ? checkClearance : 0
    readonly property real areaBottom: barOnTop ? height : height - checkClearance

    radius: Config.radius
    color: Config.surface2Color

    Image {
        anchors.fill: parent
        source: WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Config.wallpaperThumbSize
        asynchronous: true
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: root.barOnTop ? 0 : parent.height - height
        height: root.checkClearance
        color: Config.backgroundTransparentColor
    }

    // Real style at its real size, scaled from the top-left corner
    Loader {
        id: style

        readonly property real naturalWidth: item?.implicitWidth ?? 0
        readonly property real naturalHeight: item?.implicitHeight ?? 0
        // With the bar at the bottom, a top OSD keeps clear of the check
        readonly property real topLimit: root.barOnTop ? root.areaTop : root.checkClearance
        readonly property real fit: naturalWidth > 0 && naturalHeight > 0 ? Math.min(1, (root.width - root.gap * 2) / naturalWidth, (root.areaBottom - topLimit - root.gap * 2) / naturalHeight) : 1
        readonly property real drawnWidth: naturalWidth * fit
        readonly property real drawnHeight: naturalHeight * fit

        width: naturalWidth
        height: naturalHeight
        scale: fit
        transformOrigin: Item.TopLeft
        sourceComponent: root.styles[root.value] ?? pillStyle

        x: {
            if (root.edge === "left")
                return root.gap;
            if (root.edge === "right")
                return root.width - drawnWidth - root.gap;
            return (root.width - drawnWidth) / 2;
        }
        y: {
            const middle = root.areaTop + (root.areaBottom - root.areaTop - drawnHeight) / 2;
            if (root.edge === "top") {
                // Attached: flush with a docked bar, else with the screen edge
                if (root.attached)
                    return root.barOnTop && root.docked ? root.areaTop : 0;
                return topLimit + root.gap;
            }
            if (root.edge === "bottom") {
                if (root.attached)
                    return !root.barOnTop && root.docked ? root.areaBottom - drawnHeight : root.height - drawnHeight;
                return root.areaBottom - drawnHeight - root.gap;
            }
            return middle;
        }
    }

    Component {
        id: pillStyle

        PillStyle {
            value: 0.65
            icon: "\u{f057e}" // md-volume_high
        }
    }

    Component {
        id: verticalStyle

        VerticalStyle {
            value: 0.65
            icon: "\u{f057e}"
        }
    }

    Component {
        id: cardStyle

        CardStyle {
            value: 0.65
            icon: "\u{f057e}"
            label: "Volume"
        }
    }

    Component {
        id: attachedStyle

        AttachedStyle {
            value: 0.65
            icon: "\u{f057e}"
            edge: root.edge
            shown: true
        }
    }
}
