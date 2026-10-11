import QtQuick
import QtQuick.Controls

Flickable {
    id: root
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    // Room to scroll the last row out from under the floating player.
    readonly property real playerInset: Window.window && Window.window.playerInset !== undefined ? Window.window.playerInset : 0
    bottomMargin: playerInset
    ScrollBar.vertical: ScrollBar {
        bottomPadding: root.playerInset
        onPressedChanged: if (pressed) wheelAnimation.stop()
    }

    function scrollBy(delta, smooth = true) {
        wheelAnimation.scrollBy(delta, smooth);
    }

    // Mouse wheel notches add momentum; touchpad updates follow the fingers.
    ScrollWheelHandler {
        id: wheelHandler
        onWheel: function(event) {
            const motion = wheelHandler.measure(event);
            if (motion.horizontal) {
                event.accepted = false;
                return;
            }
            root.scrollBy(motion.delta, motion.smooth);
            event.accepted = true;
        }
    }
    WheelGlide {
        id: wheelAnimation
        view: root
    }
    onDraggingChanged: if (dragging) wheelAnimation.stop()
    onVisibleChanged: wheelAnimation.stop()
}
