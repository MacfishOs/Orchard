/*
 * Copyright (C) 2026 SFG545
 *
 * This file is part of Orchard.
 *
 * Orchard is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * Orchard is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 * PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Orchard. If not, see <https://www.gnu.org/licenses/>.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Orchard
import "components"
import "components/local"
import "components/player"

Window {
    id: mainWindow

    property bool troubleModalOpen: false
    readonly property bool nativeWindowFrame: Qt.platform.os === "windows"
    // Height the floating player overlaps at the bottom of scrolling pages.
    property real playerInset: 0

    function toggleMaximized() {
        if (mainWindow.visibility === Window.Maximized)
            mainWindow.showNormal();
        else
            mainWindow.showMaximized();
    }

    function toggleMiniPlayer() {
        if (miniPlayerWindow.visible) {
            miniPlayerWindow.returnToMain();
        } else {
            miniPlayerWindow.openPlayer();
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+M"
        onActivated: mainWindow.toggleMiniPlayer()
    }

    Shortcut {
        sequence: "Ctrl+Alt+M"
        onActivated: mainWindow.toggleMiniPlayer()
    }

    visible: true
    width: Math.min(OrchardWindowState.initialWidth, OrchardWindowState.availableWidth)
    height: Math.min(OrchardWindowState.initialHeight, OrchardWindowState.availableHeight)
    minimumWidth: Math.min(900, OrchardWindowState.availableWidth)
    minimumHeight: Math.min(600, OrchardWindowState.availableHeight)
    title: qsTr("Orchard")
    Component.onCompleted: {
        if (OrchardWindowState.initialMaximized)
            mainWindow.showMaximized();
    }
    color: Qt.platform.os === "linux" ? "#9018181c" : "#1c1c1f"
    flags: nativeWindowFrame ? Qt.Window : Qt.Window | Qt.FramelessWindowHint
    onClosing: close => {
        // Closing to the tray keeps the music going; the tray menu holds the real exit.
        if (OrchardTray.available && OrchardTray.closeToTray && OrchardAuth.isSignedIn) {
            close.accepted = false;
            mainWindow.hide();
            return;
        }
        Qt.quit();
    }

    // Background shader removed to minimize RAM and CPU overhead

    Item {
        id: titleBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 38
        // Stack below contentArea itself so its controls receive presses first.
        z: -1

        DragHandler {
            id: windowDragHandler

            target: null
            // Never steal a press already owned by a button or another control.
            grabPermissions: PointerHandler.ApprovesTakeOverByAnything
            onActiveChanged: {
                if (active)
                    mainWindow.startSystemMove();
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.DragThreshold
            // Two taps: the traditional shortcut for making the orchard roomy.
            onDoubleTapped: mainWindow.toggleMaximized()
        }
    }

    WindowControls {
        id: windowControls

        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 16
        targetWindow: mainWindow
        z: 10
        visible: (!mainWindow.nativeWindowFrame || mainWindow.visibility === Window.FullScreen)
        autoHide: mainWindow.visibility === Window.FullScreen && homeShell.item !== null && homeShell.item.fullscreenOpen
    }

    // Apple Music Style Header: Logo & Title placed directly next to Window Controls
    Row {
        id: appHeader
        anchors.left: windowControls.right
        anchors.leftMargin: 16
        anchors.verticalCenter: windowControls.verticalCenter
        spacing: 8
        z: 10
        visible: windowControls.visible

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            source: "assets/orchard-logo.png"
            fillMode: Image.PreserveAspectFit
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Music")
            color: "#ffffff"
            font.family: "SF Pro Display, SF Pro, Inter, sans-serif"
            font.pixelSize: 18
            font.weight: Font.Bold
            font.letterSpacing: -0.3
        }
    }

    Item {
        id: contentArea

        anchors.fill: parent

        // Passive, so it sees pointer motion even over controls that take hover themselves.
        // Animated items resend hover under a still cursor, so only real movement counts.
        HoverHandler {
            property point last: Qt.point(-1, -1)
            onPointChanged: {
                const pos = point.scenePosition;
                if (Math.abs(pos.x - last.x) < 1 && Math.abs(pos.y - last.y) < 1)
                    return;
                last = pos;
                if (windowControls.autoHide)
                    windowControls.wake();
            }
        }

        LoginView {
            id: loginView

            visible: !OrchardAuth.isSignedIn && !OrchardAuth.authWebViewActive && !OrchardAuth.profileLoading
            onLoginRequested: OrchardAuth.startLogin()
            onTroubleRequested: mainWindow.troubleModalOpen = true
        }

        Loader {
            id: homeShell

            anchors.fill: parent
            visible: active && OrchardAuth.isSignedIn && OrchardAuth.status !== "starting"
            sourceComponent: Component { HomeShell {} }
        }

        Column {
            anchors.centerIn: parent
            spacing: 12
            visible: OrchardAuth.profileLoading && !OrchardAuth.authWebViewActive

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: parent.visible
            }

            Text {
                text: qsTr("Loading your YouTube profile…")
                color: "#9299a3"
                font.pixelSize: 13
                font.family: "Inter"
            }
        }

        // Grows in from just under full size and stays loaded until its fade-out ends.
        Loader {
            id: theater

            readonly property bool shown: OrchardMusicVideo.open && homeShell.visible

            anchors.fill: parent
            active: shown || opacity > 0
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.94
            sourceComponent: Component { MusicVideoTheater {} }

            Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 560; easing.type: Easing.OutExpo } }
        }
    }

    // Owns the file dialogs behind "Add local files", covers and lyrics.
    LocalPickerHost {}

    // Above everything, including window controls, so edges stay grabbable.
    WindowResizeHandles {
        targetWindow: mainWindow
        enabled: !mainWindow.nativeWindowFrame
        z: 100
    }

    MiniPlayerWindow {
        id: miniPlayerWindow
        parentWindow: mainWindow
    }
}
