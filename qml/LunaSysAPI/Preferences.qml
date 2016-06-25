/*
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org>
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
import LuneOS.Service 1.0
import LunaNext.Common 0.1

Item {
    id: preferences

    property bool airplaneMode: false
    property bool rotationLock: rotationLockAngle!==rotationInvalid
    property int rotationLockAngle: rotationInvalid
    property bool muteSound: false

    property string wallpaperFile: ""
    readonly property int rotationInvalid: 400

    //
    // private
    //

    onAirplaneModeChanged: systemService.setPreference("airplaneMode", preferences.airplaneMode)
    onRotationLockAngleChanged: systemService.setPreference("rotationLock", preferences.rotationLockAngle)
    onMuteSoundChanged: systemService.setPreference("muteSound", preferences.muteSound)

    LunaService {
        id: systemService

        name: "org.webosports.luna"

        property variant keysToWatch: ["wallpaper","airplaneMode","rotationLock","muteSound"]

        onInitialized: {
            console.log("Calling preferences service ...");

            // subscribe to preference change events so that we know when something has changed
            // and we can notify the relevant parts of the UI about this
            systemService.subscribe("luna://com.palm.systemservice/getPreferences",
                                    JSON.stringify({"keys": keysToWatch,"subscribe":true}),
                                    handlePreferencesChanged,
                                    handleError);
        }

        function handlePreferencesChanged(message) {
            var response = JSON.parse(message.payload);

            if (response.hasOwnProperty("wallpaper")) {
                preferences.wallpaperFile = response.wallpaper.wallpaperFile;
            }
            if (response.hasOwnProperty("airplaneMode")) {
                preferences.airplaneMode = response.airplaneMode;
            }
            if (response.hasOwnProperty("rotationLock")) {
                preferences.rotationLockAngle = response.rotationLock;
            }
            if (response.hasOwnProperty("muteSound")) {
                preferences.muteSound = response.muteSound;
            }
        }

        function handleError(message) {
            console.log("Failed to call preferences service: " + message);
        }

        function setPreference(key, value) {
            var params = {};
            params[key] = value;
            systemService.call("luna://com.palm.systemservice/setPreferences",
                                    JSON.stringify(params),
                                    function (message) { },
                                    handleError);
        }
    }
}
