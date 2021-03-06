/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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
import QtGraphicalEffects 1.0

import LunaNext.Common 0.1
import LunaNext.Compositor 0.1

import "../Utils"

Item {
    id: cardGroupListViewItem

    property bool enableDragnDrop: false

    property real maximizedCardTopMargin;

    property real cardScale: 0.6
    property real cardWindowWidth: width*cardScale
    property real cardWindowHeight: height*cardScale

    property Item cardView

    property bool interactiveList: true

    signal cardRemove(Item window);
    signal cardSelect(Item window);
    signal cardDragStart(Item window);

    focus: true
    Keys.forwardTo: internalListView
    Tweak {
        id: dragNDropTweak
        owner: "luna-next-cardshell"
        key: "stackedCardSupport"
        defaultValue: "false"
        onValueChanged: updateDragNDropTweak();

        function updateDragNDropTweak()
        {
            if (dragNDropTweak.value === true){
               enableDragnDrop = true
            }
            else {
                enableDragnDrop = false
            }
        }
    }

    CardGroupModel {
        id: listCardGroupsModel

        onRowsInserted: internalListView.newCardInserted = true;
    }

    ListView {
        id: internalListView

        anchors.fill: parent

        preferredHighlightBegin: width/2-cardGroupListViewItem.cardWindowWidth/2
        preferredHighlightEnd: width/2+cardGroupListViewItem.cardWindowWidth/2
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightFollowsCurrentItem: true

        model: listCardGroupsModel
        spacing: 10
        orientation: ListView.Horizontal
        smooth: !internalListView.moving
        focus: true
        interactive: cardGroupListViewItem.interactiveList

        property bool newCardInserted: false
        onCountChanged: {
            if( newCardInserted && count > 0 ) {
                newCardInserted = false;
                var lastWindow = listCardGroupsModel.getCurrentCardOfGroup(listCardGroupsModel.get(count-1));
                if( lastWindow ) {
                    cardGroupListViewItem.cardSelect(lastWindow);
                }
            }
        }

        function setCurrentCardIndex(newIndex) {
            internalListView.currentIndex = newIndex
            if( cardView && internalListView.currentIndex>=0 ) {
                cardView.currentCardChanged(currentActiveWindow())
            }
        }

        delegate: CardGroupDelegate {
                        cardGroupListViewInstance: cardGroupListViewItem
                        groupModel: windowList

                        delegateIsCurrent: ListView.isCurrentItem

                        y: 0
                        height: cardGroupListViewItem.height
                        width: cardGroupListViewItem.cardWindowWidth

                        z: ListView.isCurrentItem ? 1 : 0

                        onCardSelect: {
                            listCardGroupsModel.setWindowInFront(window, index)
                            cardGroupListViewItem.cardSelect(window);
                        }
                        onCardRemove: cardGroupListViewItem.cardRemove(window);
                        onCardDragStart: {
                            if( !enableDragnDrop ) {
                                console.log("Drag'n'drop is currently disabled.");
                            }
                            else if( containerForDraggedCard.visible ) {
                                console.log("A Drag'n'drop transaction is already ongoing. Please drop the dragged window somewhere valid.");
                            }
                            else if( ListView.view.count >= 2 ) {
                                console.log("Entering drag'n'drop mode...");
                                window.userData.dragMode = true;
                                containerForDraggedCard.startDrag(window);
                                listCardGroupsModel.removeWindow(window);
                            }
                        }

                        // The drop area components hereunder should be moved into a separate component,
                        // for a clearer understanding.
                        DropArea {
                            anchors.fill: parent

                            onEntered: internalListView.currentIndex = index;
                            onDropped: {
                                var droppedWindowUserData = drag.source;
                                droppedWindowUserData.dragMode = false;
                                windowList.append({"window": droppedWindowUserData.wrappedWindow});
                                containerForDraggedCard.stopDrag();
                                droppedWindowUserData.dragMode = false;
                                console.log("Exited drag'n'drop mode.");
                            }
                        }
                        // This is the drop area where we drop the card between other cards
                        // So we create two drop areas on the side of each cardgroup delegate,
                        // overlapping the spacing done by the ListView.
                        Item {
                            anchors.left: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: internalListView.spacing * 0.5
                            Rectangle {
                                id: dropRectRight
                                anchors.fill: parent;
                                color: "blue"
                                opacity: 0.4
                                visible: false
                            }
                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    dropRectRight.visible = true;
                                }
                                onExited: {
                                    dropRectRight.visible = false;
                                }
                                onDropped: {
                                    var droppedWindowUserData = drag.source;
                                    droppedWindowUserData.dragMode = false;
                                    listCardGroupsModel.createNewGroup(droppedWindowUserData.wrappedWindow, index+1);
                                    internalListView.newCardInserted = false;
                                    containerForDraggedCard.stopDrag();
                                    dropRectRight.visible = false;
                                    droppedWindowUserData.dragMode = false;
                                    console.log("Exited drag'n'drop mode.");
                                }
                            }
                        }
                        Item {
                            anchors.right: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: internalListView.spacing * 0.5
                            Rectangle {
                                id: dropRectLeft
                                anchors.fill: parent;
                                color: "green"
                                opacity: 0.4
                                visible: false
                            }
                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    dropRectLeft.visible = true;
                                }
                                onExited: {
                                    dropRectLeft.visible = false;
                                }
                                onDropped: {
                                    var droppedWindowUserData = drag.source;
                                    droppedWindowUserData.dragMode = false;
                                    listCardGroupsModel.createNewGroup(droppedWindowUserData.wrappedWindow, index);
                                    internalListView.newCardInserted = false;
                                    containerForDraggedCard.stopDrag();
                                    dropRectLeft.visible = false;
                                    droppedWindowUserData.dragMode = false;
                                    console.log("Exited drag'n'drop mode.");
                                }
                            }
                        }
                }
    }

    // This item is used during a Drag'n'Drop operation, to
    // temporarily hold the dragged card
    Item {
        id: containerForDraggedCard

        visible: false
        anchors.fill: internalListView
        opacity: 0.8

        Item {
            id: cardWindowWrapper

            anchors.fill: parent

            function setDraggedWindow(windowUserData) {
                // convert position of card
                var newPos = mapFromItem(windowUserData.parent, windowUserData.x, windowUserData.y)
                // delete old anchors
                windowUserData.anchors.fill = undefined;

                // reparent
                cardWindowWrapper.children = [ windowUserData ];
                windowUserData.parent = cardWindowWrapper;

                // set correct position
                windowUserData.x = newPos.x;
                windowUserData.y = newPos.y;
                windowUserData.visible = true;
            }
        }

        function startDrag(window) {
            cardWindowWrapper.setDraggedWindow(window.userData);
            containerForDraggedCard.visible = true;
        }
        function stopDrag() {
            containerForDraggedCard.visible = false;
        }
    }

    function currentActiveWindow() {
        if( internalListView.currentIndex >= 0 ) {
            return listCardGroupsModel.getCurrentCardOfGroup(listCardGroupsModel.get(internalListView.currentIndex));
        }

        return null;
    }

    function setCurrentActiveWindow(window) {
        var foundGroupIndex = listCardGroupsModel.setCurrentCard(window);
        if( foundGroupIndex>=0 ) {
            internalListView.setCurrentCardIndex(foundGroupIndex);
        }
    }
}

