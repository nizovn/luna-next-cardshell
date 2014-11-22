/* @@@LICENSE
*
*      Copyright (c) 2009-2013 LG Electronics, Inc.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* LICENSE@@@ */

import QtQuick 2.0
import LunaNext.Common 0.1

MenuListEntry {
    id: batteryElement
    property int ident: 0
    property string batteryText: "100%"

//    Connections {
//        target: statusBarServicesConnector
//        onSignalBatteryLevelUpdated: {
//            console.log("Battery level was updated " + percentage);
//            if (percentage >= 0 && percentage <= 100)
//                batteryText = percentage + "%"
//            else
//                batteryText = "Not available";
//        }
//    }

    function updateBatteryStatus(message) {
        var response = JSON.parse(message.payload);
        batteryText = response.percent_ui + "%";
    }

    function handleError(error) {
        console.log("Could not get power status: " + error);
    }

    LunaService {
        id: service
        name: "org.webosports.luna"
        usePrivateBus: true
        onInitialized: {
            service.subscribe("palm://com.palm.bus/signal/addmatch",
                                  JSON.stringify({"category":"/com/palm/power","method":"batteryStatus"}),
                                  updateBatteryStatus, handleError);
            service.call("luna://com.palm.power/com/palm/power/batteryStatusQuery",
                              {},
                              updateBatteryStatus,
                              handleError);
        }
    }

    selectable: false
    content:
        Row {
            x: ident;
            width: parent.width
            Text {
                text: "Battery: "
                color: "#AAA";
                font.pixelSize: FontUtils.sizeToPixels("medium"); //18
                font.family: "Prelude"
            }

            Text {
                text: batteryText;
                color: "#AAA";
                font.pixelSize: FontUtils.sizeToPixels("medium"); //18;
                font.family: "Prelude"
            }
        }
}