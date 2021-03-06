/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.0
import QtQuick.Layouts 1.0
import LunaNext.Common 0.1
import LunaNext.Compositor 0.1

Item {
    id: launchBarItem

    signal startLaunchApplication(string appId, string appParams)
    signal toggleLauncherDisplay

    state: "visible"
    anchors.bottom: parent.bottom

    property real launcherBarIconSize: launchBarItem.height * 0.7;

    // list of icons
    ListModel {
        id: launcherListModel
    }

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: launchBarItem; anchors.top: parent.bottom; anchors.bottom: undefined }
            PropertyChanges { target: launchBarItem; opacity: 0 }
            PropertyChanges { target: launchBarItem; visible: false }
        },
        State {
            name: "visible"
            AnchorChanges { target: launchBarItem; anchors.top: undefined; anchors.bottom: parent.bottom }
            PropertyChanges { target: launchBarItem; opacity: 1 }
            PropertyChanges { target: launchBarItem; visible: true }
        }
    ]

    transitions: [
        Transition {
            to: "hidden"

            AnchorAnimation { easing.type:Easing.InOutQuad; duration: 150 }
            SequentialAnimation {
                NumberAnimation { property: "opacity"; duration: 150 }
                PropertyAction { property: "visible" }
            }
        },
        Transition {
            to: "visible"

            SequentialAnimation {
                PropertyAction { property: "visible" }
                ParallelAnimation {
                    AnchorAnimation { easing.type:Easing.InOutQuad; duration: 150 }
                    NumberAnimation { property: "opacity"; duration: 150 }
                }
            }
        }
    ]

    // background of quick laucnh
    Rectangle {
        anchors.fill: launchBarItem
        opacity: 0.2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "grey" }
            GradientStop { position: 1.0; color: "white" }
        }
    }

    RowLayout {
        id: launcherRow

        visible: false
        anchors.fill: launchBarItem
        spacing: 0

        Repeater {
            model: launcherListModel

            LaunchableAppIcon {
                id: launcherIcon

                Layout.fillWidth: true
                Layout.preferredHeight: launchBarItem.launcherBarIconSize
                Layout.preferredWidth: launchBarItem.launcherBarIconSize

                appIcon: model.icon
                appId: model.appId

                iconSize: launchBarItem.launcherBarIconSize

                //anchors.verticalCenter: launcherRow.verticalCenter
                height: launchBarItem.launcherBarIconSize
                width: launchBarItem.launcherBarIconSize

                onStartLaunchApplication: launchBarItem.startLaunchApplication(appId, "");
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: launchBarItem.launcherBarIconSize
            Layout.preferredWidth: launchBarItem.launcherBarIconSize

            Image {
                id: appsIcon

                anchors.right: parent.right

                height: launchBarItem.launcherBarIconSize
                width: launchBarItem.launcherBarIconSize
                fillMode: Image.PreserveAspectFit
                source: "../images/empty-launcher.png"

                MouseArea {
                    anchors.fill: parent
                    onClicked: launchBarItem.toggleLauncherDisplay()
                }
            }
        }
    }

    Component.onCompleted: {
        // fill the listModel statically
        if( !Settings.isTestEnvironment ) {
            launcherListModel.append({"appId": "org.webosports.app.phone", "icon": "/usr/palm/applications/org.webosports.app.phone/icon.png"});
            launcherListModel.append({"appId": "com.palm.app.email", "icon": "/usr/palm/applications/com.palm.app.email/icon.png"});
            launcherListModel.append({"appId": "org.webosinternals.preware", "icon": "/usr/palm/applications/org.webosinternals.preware/icon.png"});
            launcherListModel.append({"appId": "org.webosports.app.memos", "icon": "/usr/palm/applications/org.webosports.app.memos/icon.png"});
        }
        else
        {
            launcherListModel.append({"appId": "org.webosports.tests.dummyWindow", "icon": Qt.resolvedUrl("../images/default-app-icon.png")});
            launcherListModel.append({"appId": "org.webosports.tests.fakeDashboardWindow", "icon": Qt.resolvedUrl("../images/default-app-icon.png")});
            launcherListModel.append({"appId": "org.webosports.tests.fakePopupAlertWindow", "icon": Qt.resolvedUrl("../images/default-app-icon.png")});
            launcherListModel.append({"appId": "org.webosports.tests.dummyWindow", "icon": Qt.resolvedUrl("../images/default-app-icon.png")});
        }
        launcherRow.visible = true;
    }
}
