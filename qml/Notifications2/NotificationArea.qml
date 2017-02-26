/*
 * Copyright (C) 2014-2016 Christophe Chapuis <chris.chapuis@gmail.com>
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

import QtQuick 2.6
import QtQml.Models 2.1

import LunaNext.Common 0.1
import LunaNext.Compositor 0.1
import LunaNext.Shell.Notifications 0.1
import LuneOS.Service 1.0
import LunaNext.Shell 0.1

import "../Utils"

// The notification area can take three states:
//  - hidden: nothing is shown
//  - minimized: only notification icons are shown
//  - open: all notifications with their content are shown

Rectangle {
    id: notificationArea

    property QtObject compositorInstance
    property Item windowManagerInstance
    property int maxDashboardWindowHeight: parent.height/2
    readonly property int dashboardCardFixedHeight: Units.gu(5.6) // this value comes from the CSS of the dashboard cards
    readonly property Item boundingRect: visibleMinimizedView
    property bool blackMode: false

    signal clicked;

    height: 0
    color: "transparent"
    /* hidden by default as long as we don't any notifications */
    state: "hidden"

    IconPathServices {
           id: iconPathServices
    }

    NotificationManager {
        id: notificationMgr
    }

    NotificationListModel {
        id: notificationModel

        // the signal itemAdded is declared in C++, without a qmltype declaration,
        // so QML isn't able to guess the name of the signal argument.
        onItemAdded: {
            var notifObject = arguments[0];

            var createStickyNotification = ( typeof notifObject.expireTimeout !== 'undefined' && notifObject.expireTimeout > 1 );

            // Banner in all cases
            bannerItemsPopups.popupModel.append({"object" : notifObject, "sticky": createStickyNotification});

            // If the notification's duration is long enough, also add it to the notification list
            if( createStickyNotification ) {
                // Sticky notification
                mergedModel.append({"notifType": "notification",
                                    "window": null,
                                    "notifObject": notifObject,
                                    "notifHeight": dashboardCardFixedHeight});
            }
        }
        onRowsAboutToBeRemoved: {
            var notifObject = notificationModel.get(last);
            for( var i=0; i<mergedModel.count; ++i ) {
                if( mergedModel.get(i).notifObject &&
                    mergedModel.get(i).notifObject.replacesId === notifObject.replacesId ) {
                    mergedModel.remove(i);
                    break;
                }
            }
        }
    }
    WindowModel {
        id: listDashboardsModel
        windowTypeFilter: WindowType.Dashboard

        onRowsInserted: {
            var window = listDashboardsModel.getByIndex(last);
            window.visible = false;

            // Handle dashboards with custom height
            var dashHeight = 0;
            if( window.windowProperties && window.windowProperties.hasOwnProperty("LuneOS_dashheight") )
            {
                //If the provide it in GridUnits we need to make sure we deal with it properly.
                if( window.windowProperties.hasOwnProperty("LuneOS_metrics") && window.windowProperties["LuneOS_metrics"]==="units")
                {
                    dashHeight = Units.gu(window.windowProperties["LuneOS_dashheight"]);
                }
                //Provided in normal pixels, convert to device pixels
                else
                {
                    dashHeight = Units.length(window.windowProperties["LuneOS_dashheight"]);
                }
            }
            if( dashHeight<=0 ) dashHeight = dashboardCardFixedHeight;

            if( notificationArea.state === "hidden" || notificationArea.state == "open" ) {
                notificationArea.state = "minimized";
            }
            mergedModel.append({"notifType": "dashboard",
                                "window": window,
                                "notifObject": null,
                                "notifHeight": dashHeight});
        }
        onRowsAboutToBeRemoved: {
            var window = listDashboardsModel.getByIndex(last);
            for( var i=0; i<mergedModel.count; ++i ) {
                if( mergedModel.get(i).window && mergedModel.get(i).window === window ) {
                    mergedModel.remove(i);
                    break;
                }
            }
        }
    }

    ListModel {
        id: mergedModel
        dynamicRoles: true
    }

    Component {
        id: notificationItemDelegate

        NotificationItem {
            id: notificationItem

            property var notifObject: loaderNotifObject;

            signal clicked()
            signal closed(int notifIndex)

            title: notifObject.title
            body: notifObject.body
            bgColor: "transparent"

            Component.onCompleted: {
                iconPathServices.setIconUrlOrDefault(notifObject.iconPath, notifObject.ownerId, function(resolvedUrl) { notificationItem.iconUrl = resolvedUrl; });
            }

            onClosed: {
                notificationMgr.closeById(notifObject.replacesId);
            }

            MouseArea {
                anchors.fill: parent
                onClicked: launcherInstance.launchApplication(notificationItem.notifObject.launchId,
                                                              notificationItem.notifObject.launchParams, handleLaunchAppSuccess);

															  
            }

            function handleLaunchAppSuccess() {
                if (typeof notifObject.replacesId !== "undefined") {
                    notificationMgr.closeById(notifObject.replacesId);
                }
            }
        }
    }
    Component {
        id: dashboardDelegate

        Item {
            id: dashboardItem

            property Item dashboardWindow: loaderWindow;

            signal clicked()
            signal closed(int notifIndex)

            onWidthChanged: if(dashboardWindow) dashboardWindow.changeSize(Qt.size(dashboardItem.width, dashboardItem.height));

            children: [ dashboardWindow ]

            Component.onCompleted: {
                if( dashboardWindow ) {
                    dashboardWindow.parent = dashboardItem;

                    /* This resizes only the quick item which contains the child surface but
                                             * doesn't really resize the client window */
                    dashboardWindow.anchors.fill = dashboardItem;
                    dashboardWindow.visible = true;

                    /* Resize the real client window to have the right size */
                    dashboardWindow.changeSize(Qt.size(dashboardItem.width, dashboardItem.height));
                }
            }
            Component.onDestruction: {
                if( dashboardWindow ) dashboardWindow.visible = false;
            }

            onClosed: {
                dashboardWindow.visible = false;
                compositorInstance.closeWindowWithId(dashboardWindow.winId); // this will take care of removing the card from mergedModel
                dashboardWindow = null;
            }
        }
    }

    Item {
        id: visibleMinimizedView
        anchors.right: minimizedListView.right
        anchors.top: minimizedListView.top
        anchors.bottom: minimizedListView.bottom
        width: minimizedListView.visible? minimizedListView.width+statusBarSeparator.width : 0;
    }

    Image {
        id: statusBarSeparator
        source: "../images/statusbar/status-bar-separator.png"
        anchors.verticalCenter: minimizedListView.verticalCenter
        anchors.right: minimizedListView.left
        height: notificationArea.height
        width: 2
        mipmap: true
        visible: minimizedListView.visible
    }

    BorderImage {
        id: minimizedViewOpenBg
        visible: openListView.visible && !notificationArea.blackMode
        source: "../images/statusbar/status-bar-menu-dropdown-tab.png"
        anchors.top: visibleMinimizedView.top
        anchors.bottom: visibleMinimizedView.bottom
        width: visibleMinimizedView.width+19
        x: visibleMinimizedView.x-9
        smooth: false
        border.left: 11
        border.right: 11
        border.top: 2
    }

    // Minimized view
    Row {
        id: minimizedListView

        anchors {
            bottom: parent.bottom
            top: parent.top
            right: parent.right
        }

        spacing: Units.gu(1)/2
        padding: Units.gu(1)/2
        visible: mergedModel.count > 0

        layoutDirection: Qt.RightToLeft

        Image {
            id: menuArrow
            source: "../images/statusbar/menu-arrow.png"
            anchors.verticalCenter: parent.verticalCenter
            height: Units.gu(2.6)
            width: Units.gu(1.5)
            mipmap: true
            visible: !notificationArea.blackMode
        }

        Repeater {
            model: mergedModel
            delegate: Image {
                    id: notifIconImage
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: Units.gu(1)/2
                    width: height
                    fillMode: Image.PreserveAspectFit

                    function setSourceIcon(resolvedUrl) {
                        notifIconImage.source = resolvedUrl;
                    }

                    // set the source asynchronously
                    Component.onCompleted: {
                        // if it's a dashboard, iconUrl is equal to: getIconUrl(myIconUrl, window.appId),
                        // if it's a notification, it's simply getIconUrlOrDefault(iconUrl, ownerId, "mergedModel")

                        // so, if it's a window, we need to call setIconUrlFromWindow first
                        if(model.window) {
                            iconPathServices.setIconUrlFromWindow(model.window, function(resolvedUrl) {
                                iconPathServices.setIconUrlOrDefault(resolvedUrl, window.appId, setSourceIcon);
                            });
                        } else if(notifObject) {
                            iconPathServices.setIconUrlOrDefault(notifObject.iconPath, notifObject.ownerId, setSourceIcon);
                        }
                    }

            }
        }
    }

    function minimizeNotificationArea() {
        if( notificationArea.state === "open" )
            notificationArea.state = "minimized";
    }

    MouseArea {
        anchors.fill: minimizedListView
        enabled: minimizedListView.visible
        onClicked: {
            notificationArea.clicked();
        }
    }

    onClicked: {
        if (notificationArea.blackMode)
            return;
        bannerItemsPopups.popupModel.clear();
        if (notificationArea.state === "minimized") {
            notificationArea.state = "open";
            windowManagerInstance.addTapAction("minimizeNotificationArea", minimizeNotificationArea, null)
        }
        else if (notificationArea.state === "open") {
            notificationArea.state = "minimized";
            windowManagerInstance.removeTapAction("minimizeNotificationArea")
        }
    }

    InverseMouseArea {
        anchors.fill: openListView
        enabled: openListView.visible
        sensingArea: root
        z: -1
        onClicked: {
            notificationArea.clicked();
        }
    }

    BorderImage {
        id: openListViewBg
        source: "../images/menu-dropdown-bg.png"
        x: openListView.x-11
        y: openListView.y
        z: -1
        width: openListView.width+22
        height: openListView.height+14
        smooth: false
        border { left: 30; top: 10; right: 30; bottom: 30 }
        visible: openListView.visible
    }

    ListView {
        id: openListView

        visible: false
        interactive: height === maxDashboardWindowHeight
        clip: true
        orientation: ListView.Vertical
        cacheBuffer: maxDashboardWindowHeight
        height: Math.min(maxDashboardWindowHeight, contentHeight);
        width: Units.gu(30)
        anchors {
            top: parent.bottom
            right: parent.right
        }

        MouseArea {
            anchors.fill: parent
            z: -1
        }

        Item {
            id: maskTop
            z:10
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            opacity: !parent.atYBeginning ? 1.0 : 0.0

            Image {
                width: parent.width
                height: Units.gu(3)
                source: "../images/menu-dropdown-scrollfade-top.png"
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                y:0
                width: Units.gu(2.1)
                height: Units.gu(2.1)
                source: "../images/menu-arrow-up.png"
            }
        }

        Item {
            id: maskBottom
            z:10
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - scrollfadeBottom.height + 1
            opacity: !parent.atYEnd? 1.0 : 0.0

            Image {
                id: scrollfadeBottom
                width: parent.width
                height: Units.gu(3)
                source: "../images/menu-dropdown-scrollfade-bottom.png"
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Units.gu(0.9)
                width: Units.gu(2.1)
                height: Units.gu(2.1)
                source: "../images/menu-arrow-down.png"
            }
        }
        spacing: 2
        model: mergedModel

        delegate:
            SwipeableNotification {
                id: slidingNotificationArea

                property var delegateNotifObject: typeof notifObject !== 'undefined' ? notifObject : undefined;
                property Item delegateWindow: typeof window !== 'undefined' ? window : null;
                property string delegateType: notifType;
                property int delegateHeight: notifHeight
                property int delegateIndex: index

                notifComponent: notificationItemLoaderComponent
                blockSwipesToLeft: true

                height: delegateHeight
                width: openListView.width
                x: 0

                Image {
                    width: parent.width
                    height: Units.gu(0.2)
                    source: "../images/menu-divider.png"
                    anchors.top: parent.bottom
                    anchors.topMargin: (openListView.spacing-height)/2.
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: delegateIndex < openListView.model.count-1
                }

                Component {
                    id: notificationItemLoaderComponent

                    Loader {
                        id: notificationItemLoader
                        width: slidingNotificationArea.width
                        height: slidingNotificationArea.delegateHeight

                        sourceComponent: slidingNotificationArea.delegateType === "notification" ? notificationItemDelegate : dashboardDelegate
                        property var loaderNotifObject: slidingNotificationArea.delegateNotifObject
                        property Item loaderWindow: slidingNotificationArea.delegateWindow

                        signal closed()
                        onClosed: {
                            item.closed(slidingNotificationArea.delegateIndex);
                        }
                    }
                }

                onRequestDestruction: slidingNotificationArea.notifItem.closed();
        }

        Behavior on height {
            NumberAnimation { duration: 150 }
        }
    }

    Image {
        source: "../images/statusbar/status-bar-separator.png"
        anchors.verticalCenter: bannerItemsPopups.verticalCenter
        height: bannerItemsPopups.height
        x: bannerItemsPopups.x+bannerItemsPopups.width-bannerItemsPopups.visibleWidth - width
        width: 2
        mipmap: true
        visible: bannerItemsPopups.visible
    }

    // Banner popup view
    BannerPopupArea {
        id: bannerItemsPopups
        visible: notificationArea.state === "banner"
        color: "transparent"

        anchors {
            bottom: parent.bottom
            right: parent.right
        }

        height: parent.height
        width: Units.gu(30)

        Connections {
            target: bannerItemsPopups.popupModel
            onCountChanged: {
                if( bannerItemsPopups.popupModel.count > 0 )
                    notificationArea.state = "banner";
                else if( mergedModel.count > 0 )
                    notificationArea.state = "minimized";
            }
            onRowsAboutToBeRemoved: {
                if( !bannerItemsPopups.popupModel.get(last).sticky )
                {
                    notificationMgr.closeById(bannerItemsPopups.popupModel.get(last).object.replacesId);
                }
            }
        }
    }

    states: [
        State {
            name: "hidden"
            when: (bannerItemsPopups.popupModel.count + mergedModel.count) === 0
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: false }
            PropertyChanges { target: notificationArea; height: 0 }
        },
        State {
            name: "banner"
            PropertyChanges { target: minimizedListView; visible: false }
            PropertyChanges { target: openListView; visible: false }
        },
        State {
            name: "minimized"
            PropertyChanges { target: minimizedListView; visible: true }
            PropertyChanges { target: openListView; visible: false }
        },
        State {
            name: "open"
            PropertyChanges { target: openListView; visible: true }
        }
    ]

    // have an object that surveys the count of notifications and notify the display if something interesting happens
    QtObject {
        property int count: mergedModel.count
        onCountChanged: {
            if (count === 0 && __previousCount !== 0) {
                // notify the display
                displayService.call("luna://com.palm.display/control/alert",
                                    JSON.stringify({"status": "banner-deactivated"}), undefined, onDisplayControlError)
            }
            else if (count !== 0 && __previousCount === 0){
                // notify the display
                displayService.call("luna://com.palm.display/control/alert",
                                    JSON.stringify({"status": "banner-activated"}), undefined, onDisplayControlError)
            }

            __previousCount = count;
        }
        function onDisplayControlError(message) {
            console.log("Failed to call display service: " + message);
        }
        property int __previousCount: 0
    }
    LunaService {
        id: displayService

        name: "org.webosports.luna"
        usePrivateBus: true
    }
}
