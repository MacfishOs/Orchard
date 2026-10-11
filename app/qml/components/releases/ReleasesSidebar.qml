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


pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

// Release list, newest first, with a search box over versions, titles and notes.
ColumnLayout {
    id: root

    // Entries built by ReleasesView; already filtered.
    property var entries: []
    property string currentVersion
    property string filter: ""

    signal selected(string version)
    signal filterEdited(string text)

    function focusSearch() {
        search.forceActiveFocus();
    }

    onFilterChanged: {
        if (search.text !== root.filter)
            search.text = root.filter;
    }

    spacing: 0

    Text {
        text: qsTr("Releases")
        color: "#8d968e"
        font.family: "Inter"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
        Layout.leftMargin: 32
        Layout.topMargin: 26
        Layout.bottomMargin: 12
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 16
        Layout.preferredHeight: 40
        radius: 10
        color: search.activeFocus ? "#1affffff" : "#10ffffff"
        border.color: search.activeFocus ? "#8cc5a5" : "#1cffffff"
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        LucideIcon {
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            width: 15
            height: 15
            name: "search"
            color: "#a4aaa1"
        }
        TextField {
            id: search
            anchors.fill: parent
            leftPadding: 38
            rightPadding: 36
            placeholderText: qsTr("Search release notes")
            placeholderTextColor: "#7c857f"
            color: "#f0eee7"
            font.family: "Inter"
            font.pixelSize: 13
            background: Item {}
            Accessible.name: placeholderText
            onTextEdited: root.filterEdited(text)
        }
        Button {
            id: clearButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 5
            width: 28
            height: 28
            visible: search.text.length > 0
            hoverEnabled: true
            Accessible.name: qsTr("Clear search")
            onClicked: {
                search.clear();
                root.filterEdited("");
                search.forceActiveFocus();
            }
            contentItem: LucideIcon {
                name: "x"
                color: "#d6d9d3"
            }
            background: Rectangle {
                radius: 14
                color: clearButton.hovered ? "#20ffffff" : "transparent"
            }
        }
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: 10
        leftMargin: 20
        rightMargin: 16
        bottomMargin: 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.entries
        currentIndex: root.entries.findIndex(entry => entry.version === root.currentVersion)
        highlightMoveDuration: 260
        highlightMoveVelocity: -1
        highlightResizeDuration: 0
        highlightFollowsCurrentItem: true
        highlight: Item {
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                radius: 10
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#338cc4a0" }
                    GradientStop { position: 1.0; color: "#1a8cc4a0" }
                }
                border.color: "#38a0d6b4"
            }
        }
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        onCurrentIndexChanged: {
            if (list.currentIndex >= 0)
                list.positionViewAtIndex(list.currentIndex, ListView.Contain);
        }

        delegate: ItemDelegate {
            id: row
            required property var modelData
            readonly property bool current: row.modelData.version === root.currentVersion

            width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
            height: 58
            topInset: 1
            bottomInset: 1
            leftPadding: 12
            rightPadding: 12
            hoverEnabled: true
            Accessible.name: qsTr("%1, %2, %3").arg(row.modelData.version).arg(row.modelData.title).arg(row.modelData.dateLabel)
            onClicked: root.selected(row.modelData.version)

            contentItem: ColumnLayout {
                spacing: 3
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.version
                        elide: Text.ElideRight
                        color: row.current ? "#f0eee7" : "#d6d9d3"
                        font.family: "Inter"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: row.modelData.dateLabel
                        color: "#8d968e"
                        font.family: "Inter"
                        font.pixelSize: 11
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.title
                        elide: Text.ElideRight
                        color: row.current ? "#c9ccc4" : "#a3ada5"
                        font.family: "Inter"
                        font.pixelSize: 12
                    }
                    ReleaseChip {
                        visible: row.modelData.isNew
                        text: qsTr("New")
                        tone: "#e8c47c"
                    }
                    ReleaseChip {
                        visible: row.modelData.installed
                        text: qsTr("Installed")
                    }
                }
            }
            background: Rectangle {
                radius: 10
                color: row.current ? "transparent" : row.down ? "#22ffffff" : row.hovered ? "#14ffffff" : "transparent"
                border.color: row.visualFocus ? "#a6d4bf" : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 48
            visible: root.entries.length === 0
            text: root.filter.trim().length > 0 ? qsTr("No releases match “%1”").arg(root.filter.trim())
                                                : qsTr("No release notes are included with this build.")
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#8d968e"
            font.family: "Inter"
            font.pixelSize: 13
        }
    }
}
