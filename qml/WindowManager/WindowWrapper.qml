import QtQuick 2.0
import QtGraphicalEffects 1.0
import LunaNext 0.1

import "../Utils"

Item {
    id: windowWrapper

    // the window app that will be wrapped in this window container
    property alias wrappedWindow: childWrapper.wrappedChild
    // a backlink to the window manager instance
    property variant windowManager

    //   Available window states:
    //    * Carded
    //    * Maximized
    //    * Fullscreen
    property int windowState: WindowState.Carded

    // that part should be moved to a window manager, or maybe to the card view interface
    property variant cardViewParent

    // this is the radius that should be applied to the corners of this window container
    property real cornerRadius: 20

    // A simple container, to facilite the wrapping
    Item {
        id: childWrapper
        property variant wrappedChild

        anchors.fill: parent;

        function setWrappedChild(window) {
            window.parent = childWrapper;
            childWrapper.wrappedChild = window;
            childWrapper.children = [ window ];

            /* This resizes only the quick item which contains the child surface but
             * doesn't really resize the client window */
            window.anchors.fill = childWrapper;

            /* Resize the real client window to have the right size */
            window.changeSize(Qt.size(windowManager.defaultWindowWidth, windowManager.defaultWindowHeight));
        }

        function postEvent(event) {
            if( wrappedChild && wrappedChild.postEvent )
                wrappedChild.postEvent(event);
             console.log("Wrapped window: postEvent(" + event + ")");
        }
    }

    // Rounded corners
    RoundedItem {
        id: cornerStaticMask
        anchors.fill: parent
        visible: false
        cornerRadius: windowWrapper.cornerRadius
    }
    CornerShader {
        id: cornerShader
        anchors.fill: parent
        sourceItem: null
        radius: cornerRadius
        visible: false
    }
    state: windowState === WindowState.Fullscreen ? "fullscreen" : windowState === WindowState.Maximized ? "maximized" : "card"

    states: [
        State {
           name: "unintialized"
           PropertyChanges { target: windowWrapper; Keys.forwardTo: [] }
        },
        State {
           name: "card"
           PropertyChanges { target: windowWrapper; Keys.forwardTo: [] }
        },
        State {
           name: "maximized"
           PropertyChanges { target: windowWrapper; Keys.forwardTo: [ wrappedWindow ] }
        },
        State {
           name: "fullscreen"
           PropertyChanges { target: windowWrapper; Keys.forwardTo: [ wrappedWindow ] }
       }
    ]

    ParallelAnimation {
        id: newParentAnimation
        running: false

        property alias targetNewParent: parentChangeAnimation.newParent
        property alias targetWidth: widthTargetAnimation.to
        property alias targetHeight: heightTargetAnimation.to
        property bool useShaderForNewParent: false

        ParentAnimation {
            id: parentChangeAnimation
            target: windowWrapper
        }
        NumberAnimation {
            id: coordTargetAnimation
            target: windowWrapper
            properties: "x,y"; to: 0; duration: 150
        }
        NumberAnimation {
            id: widthTargetAnimation
            target: windowWrapper
            properties: "width"; duration: 150
        }
        NumberAnimation {
            id: heightTargetAnimation
            target: windowWrapper
            properties: "height"; duration: 150
        }
        NumberAnimation {
            id: scaleTargetAnimation
            target: windowWrapper
            properties: "scale"; to: 1; duration: 100
        }

        onStarted: {
            windowWrapper.anchors.fill = undefined;
            if( useShaderForNewParent )
            {
                cornerShader.sourceItem = childWrapper;
                cornerShader.visible = true;
                cornerStaticMask.visible = false;
            }
        }

        onStopped: {
            windowWrapper.anchors.fill = targetNewParent;
            if( !useShaderForNewParent )
            {
                cornerShader.sourceItem = null;
                cornerShader.visible = false;
                cornerStaticMask.visible = true;
            }
        }
    }

    function setWrappedWindow(window) {
        childWrapper.setWrappedChild(window);
    }

    function setAsCurrentWindow() {
        windowManager.setWindowAsActive(windowWrapper);
    }

    function switchToState(newState)
    {
        windowManager.setWindowAsActive(windowWrapper)

        if( newState === WindowState.Maximized ) {
            windowManager.maximizedMode()
        }
        else if( newState === WindowState.Fullscreen ) {
            windowManager.fullscreenMode()
        }
        else {
            windowManager.cardViewMode()
        }
    }

    function setNewParent(newParent, useShader) {
        newParentAnimation.targetNewParent = newParent;
        newParentAnimation.targetWidth = newParent.width;
        newParentAnimation.targetHeight = newParent.height;
        newParentAnimation.useShaderForNewParent = useShader;
        newParentAnimation.start();

    }

    function startupAnimation() {
        // do the whole startup animation
        // first: show as card in the cardview
        windowManager.setWindowAsActive(windowWrapper);
        windowManager.cardViewMode();
        newParentAnimation.complete(); // force animation to complete now
        windowManager.maximizedMode();
    }

    function postEvent(event) {
        childWrapper.postEvent(event);
    }
}