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

import "../home"
import QtQuick
import QtQuick.Effects

// Blurred cover underneath, warped cover on top once it has a frame.
Item {
    id: backdrop

    property color inkColor: "#0b0d0a"
    property url thumbnail: ""
    // 0 closed, 1 open.
    property real reveal: 1
    // Solo (0) to side-by-side (1) layout; darkens the lyrics edge.
    property real split: 0
    // Drifts and warps only while playing on screen.
    property bool playing: false
    property bool warpRunning: false
    property bool warpThrottled: false
    property real warpSpeed: 1
    property real warpIntensity: 1
    property real warpSaturation: 1
    property real warpBrightness: 0
    readonly property real stage0: 1 - Math.pow(1 - Math.max(0, Math.min(1, reveal)), 3)

    opacity: stage0
    clip: true

    Rectangle {
        anchors.fill: parent
        color: Qt.darker(backdrop.inkColor, 1.3)
    }

    Image {
        id: blurSource
        anchors.centerIn: parent
        width: Math.max(parent.width, parent.height) * 1.4
        height: width
        source: backdrop.thumbnail
        sourceSize.width: 256
        sourceSize.height: 256
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0.001
    }

    property real fallbackOpacity: blurSource.status === Image.Ready ? 0.9 : 0
    Behavior on fallbackOpacity { NumberAnimation { duration: 300 } }

    // Permanent high-vibrancy Gaussian artwork blur (never turns black, 0% CPU/GPU idle load)
    MultiEffect {
        anchors.fill: blurSource
        source: blurSource
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.65
        brightness: 0.08
        opacity: backdrop.fallbackOpacity
    }

    // Soft contrast wash so text reads clearly while keeping the luminous artwork colors vibrant
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(0.05, 0.05, 0.08, 0.28) }
            GradientStop { position: 0.45; color: Qt.rgba(0.05, 0.05, 0.08, 0.12) }
            GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.05, 0.08, 0.22 + 0.1 * backdrop.split) }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.05, 0.05, 0.08, 0.20) }
            GradientStop { position: 0.3; color: "transparent" }
            GradientStop { position: 0.75; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.05, 0.08, 0.30) }
        }
    }
}
