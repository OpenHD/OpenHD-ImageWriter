import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Item {
    id: root

    property var mainWindow: null
    property string apiBaseUrl: "https://openhd.tech"
    property string portalUrl: "https://openhd.tech/fleetcontrol"
    property string username: ""
    property string password: ""
    property string accountName: ""
    property string accountRole: ""
    property string message: ""
    property bool checkingSession: false
    property bool submitting: false
    property bool signedIn: accountName !== ""
    property bool showPassword: false
    property bool loadingProfiles: false
    property bool savingProfile: false

    ListModel { id: profileModel }

    function request(method, path, body, callback) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                callback(xhr, parseResponse(xhr))
        }
        xhr.open(method, apiBaseUrl + path)
        xhr.timeout = 15000
        if (body !== undefined)
            xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(body === undefined ? null : JSON.stringify(body))
    }

    function loadProfiles() {
        loadingProfiles = true
        message = ""
        request("GET", "/api/imagewriter/profiles", undefined, function(xhr, response) {
            loadingProfiles = false
            profileModel.clear()
            if (xhr.status >= 200 && xhr.status < 300 && response.profiles) {
                for (var i = 0; i < response.profiles.length; ++i) {
                    var profile = response.profiles[i]
                    profileModel.append({
                        "profileId": profile.id,
                        "profileName": profile.name,
                        "profileDescription": profile.description || "",
                        "profileSettings": profile.openhdSettings || ({}),
                        "profileQOpenHDConfig": profile.qopenhdConfig || ""
                    })
                }
            } else {
                message = response.message || qsTr("FleetControl profiles are not available yet.")
            }
        })
    }

    function currentOpenHDSettings() {
        return {
            "bootType": imageWriter.getValue("bootType"),
            "sbc": imageWriter.getValue("sbc"),
            "camera": imageWriter.getValue("camera"),
            "camera2": imageWriter.getValue("camera2"),
            "cameraResolution": imageWriter.getValue("cameraResolution"),
            "camera2Resolution": imageWriter.getValue("camera2Resolution"),
            "cameraPort": imageWriter.getValue("cameraPort"),
            "camera2Port": imageWriter.getValue("camera2Port"),
            "ipCameraAddress": imageWriter.getValue("ipCameraAddress"),
            "ipCameraPipeline": imageWriter.getValue("ipCameraPipeline"),
            "camera2IpCameraAddress": imageWriter.getValue("camera2IpCameraAddress"),
            "camera2IpCameraPipeline": imageWriter.getValue("camera2IpCameraPipeline"),
            "ipCameraBitrate": parseInt(imageWriter.getValue("ipCameraBitrate")) || 2,
            "displayForceMode": imageWriter.getBoolSetting("displayForceMode"),
            "displayWidth": parseInt(imageWriter.getValue("displayWidth")) || 1920,
            "displayHeight": parseInt(imageWriter.getValue("displayHeight")) || 1080,
            "displayRefreshHz": parseInt(imageWriter.getValue("displayRefreshHz")) || 60,
            "mode": imageWriter.getValue("mode"),
            "hotSpot": imageWriter.getValue("hotSpot"),
            "beep": imageWriter.getBoolSetting("beep"),
            "eject": imageWriter.getBoolSetting("eject"),
            "streamToFleetcontrol": typeof streamToPlatformSwitch !== "undefined" ? streamToPlatformSwitch.checked : false,
            "useSettings": true
        }
    }

    function saveCurrentProfile() {
        if (profileNameField.text.trim().length < 2) {
            saveMessage.text = qsTr("Give the profile a name with at least two characters.")
            return
        }

        var qopenhdConfig = ""
        var qopenhdPath = imageWriter.getValue("qopenhdConfPath")
        if (qopenhdPath.length > 0)
            qopenhdConfig = imageWriter.readTextFile(qopenhdPath)

        savingProfile = true
        saveMessage.text = ""
        request("POST", "/api/imagewriter/profiles", {
            "name": profileNameField.text.trim(),
            "description": profileDescriptionField.text.trim(),
            "openhdSettings": currentOpenHDSettings(),
            "qopenhdConfig": qopenhdConfig
        }, function(xhr, response) {
            savingProfile = false
            if (xhr.status >= 200 && xhr.status < 300 && response.profile) {
                saveProfilePopup.close()
                loadProfiles()
                message = qsTr("Profile saved to FleetControl.")
            } else {
                saveMessage.text = response.message || qsTr("The profile could not be saved.")
            }
        })
    }

    function applyProfile(profileId, profileName, settings, qopenhdConfig) {
        for (var key in settings) {
            if (settings.hasOwnProperty(key))
                imageWriter.setSetting(key, settings[key])
        }

        if (qopenhdConfig.length > 0) {
            var stagedPath = imageWriter.stageFleetControlQOpenHDConfig(profileId, qopenhdConfig)
            if (stagedPath.length === 0) {
                message = qsTr("The QOpenHD configuration could not be prepared locally.")
                return
            }
            imageWriter.setSetting("qopenhdConfPath", stagedPath)
        } else {
            imageWriter.setSetting("qopenhdConfPath", "")
        }

        message = qsTr("Profile applied. Choose an image to continue.")
        if (mainWindow && mainWindow.writeWithFleetControlProfile)
            mainWindow.writeWithFleetControlProfile(profileName)
    }

    function deleteProfile(profileId) {
        request("DELETE", "/api/imagewriter/profiles/" + encodeURIComponent(profileId), undefined,
                function(xhr, response) {
            if (xhr.status >= 200 && xhr.status < 300)
                loadProfiles()
            else
                message = response.message || qsTr("The profile could not be deleted.")
        })
    }

    function parseResponse(xhr) {
        try {
            return JSON.parse(xhr.responseText)
        } catch (error) {
            return ({})
        }
    }

    function checkSession() {
        checkingSession = true
        message = ""

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            checkingSession = false
            var response = parseResponse(xhr)
            if (xhr.status >= 200 && xhr.status < 300 && response.account) {
                accountName = response.account.displayName || response.account.username || qsTr("Operator")
                accountRole = response.account.role || ""
                loadProfiles()
            } else {
                var savedUser = imageWriter.getValue("fleetcontrol_username")
                var savedPass = imageWriter.getValue("fleetcontrol_password")
                if (savedUser && savedPass) {
                    username = savedUser
                    password = savedPass
                    authenticate()
                }
            }
        }
        xhr.open("GET", apiBaseUrl + "/api/session")
        xhr.timeout = 10000
        xhr.send()
    }

    function authenticate() {
        if (username.trim().length === 0 || password.length === 0) {
            message = qsTr("Enter both your operator ID and passphrase.")
            return
        }

        submitting = true
        message = ""
        var submittedPassword = password
        password = ""
        var currentUsername = username.trim()

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            submitting = false
            var passToSave = submittedPassword
            submittedPassword = ""
            var response = parseResponse(xhr)
            if (xhr.status >= 200 && xhr.status < 300 && response.ok && response.account) {
                accountName = response.account.displayName || response.account.username || currentUsername
                accountRole = response.account.role || ""
                message = ""
                imageWriter.setSetting("fleetcontrol_username", currentUsername)
                imageWriter.setSetting("fleetcontrol_password", passToSave)
                loadProfiles()
            } else if (xhr.status === 0) {
                message = qsTr("Unable to reach the secure FleetControl gateway.")
            } else {
                message = response.message || qsTr("Access denied. Check your credentials and try again.")
            }
        }
        xhr.open("POST", apiBaseUrl + "/api/login")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 15000
        xhr.send(JSON.stringify({ "username": currentUsername, "password": submittedPassword }))
    }

    function signOut() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                accountName = ""
                accountRole = ""
                username = ""
                password = ""
                message = ""
                imageWriter.setSetting("fleetcontrol_username", "")
                imageWriter.setSetting("fleetcontrol_password", "")
                profileModel.clear()
            }
        }
        xhr.open("POST", apiBaseUrl + "/api/logout")
        xhr.timeout = 10000
        xhr.send()
    }

    Component.onCompleted: checkSession()

    Rectangle {
        anchors.fill: parent
        color: "#0d1b26"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.width < 700 ? 24 : 42
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 11

            Image {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                source: "../icons/ui/fleetcontrol.svg"
                fillMode: Image.PreserveAspectFit
            }

            Column {
                spacing: 0

                Text {
                    text: "OPENHD"
                    color: "#eef7fa"
                    font.pixelSize: 15
                    font.bold: true
                    font.letterSpacing: 2.2
                }

                Text {
                    text: "FLEETCONTROL"
                    color: "#69828d"
                    font.pixelSize: 8
                    font.letterSpacing: 1.5
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: checkingSession ? "#607784" : "#00a6f2"
                }

                Text {
                    text: checkingSession ? qsTr("CHECKING GATEWAY") : qsTr("SECURE GATEWAY ONLINE")
                    color: "#82979f"
                    font.family: "Courier New"
                    font.pixelSize: 9
                    font.letterSpacing: 1.1
                }
            }
        }

        Item { Layout.fillHeight: true }

        GridLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 980
            Layout.alignment: Qt.AlignHCenter
            columns: root.width >= 820 ? 2 : 1
            columnSpacing: 64
            rowSpacing: 28

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                visible: root.width >= 820 && !root.signedIn

                Text {
                    text: "01   " + qsTr("COMMAND ACCESS")
                    color: "#79a0af"
                    font.family: "Courier New"
                    font.pixelSize: 10
                    font.letterSpacing: 1.4
                }

                Item { Layout.preferredHeight: 22 }

                Text {
                    text: qsTr("One fleet.")
                    color: "#eef7fa"
                    font.pixelSize: 46
                    font.weight: Font.Medium
                }

                Text {
                    text: qsTr("Total control.")
                    color: "#00a6f2"
                    font.pixelSize: 46
                    font.weight: Font.Medium
                }

                Item { Layout.preferredHeight: 18 }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Securely coordinate every aircraft, link, and mission from one operational command layer.")
                    color: "#8198a2"
                    font.pixelSize: 13
                    lineHeight: 1.45
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.maximumWidth: 430
                Layout.preferredHeight: 390
                Layout.alignment: Qt.AlignHCenter
                visible: !root.signedIn
                color: "#152130"
                border.width: 1
                border.color: "#263a4d"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.width < 700 ? 25 : 36
                    spacing: 0

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 21
                        color: "#112a3b"
                        border.color: "#1c4a6b"

                        Text {
                            anchors.centerIn: parent
                            text: root.signedIn ? "\u2713" : "\u25a3"
                            color: "#00a6f2"
                            font.pixelSize: 19
                            font.bold: true
                        }
                    }

                    Item { Layout.preferredHeight: 12 }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.signedIn ? qsTr("SESSION ACTIVE") : qsTr("AUTHORIZED PERSONNEL")
                        color: "#71878b"
                        font.family: "Courier New"
                        font.pixelSize: 8
                        font.letterSpacing: 1.4
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        text: root.signedIn ? accountName : qsTr("Secure sign in")
                        color: "#eff7f9"
                        font.pixelSize: 22
                        font.weight: Font.Medium
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        visible: root.signedIn
                        text: accountRole.length > 0 ? accountRole.toUpperCase() : qsTr("OPERATOR")
                        color: "#00a6f2"
                        font.family: "Courier New"
                        font.pixelSize: 9
                        font.letterSpacing: 1.2
                    }

                    Item { Layout.preferredHeight: root.signedIn ? 32 : 20 }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: !root.signedIn
                        spacing: 6

                        Text {
                            text: qsTr("OPERATOR ID")
                            color: "#809295"
                            font.family: "Courier New"
                            font.pixelSize: 8
                            font.letterSpacing: 1.1
                        }

                        TextField {
                            id: usernameField
                            Layout.fillWidth: true
                            placeholderText: qsTr("Enter operator ID")
                            text: root.username
                            selectByMouse: true
                            enabled: !root.submitting && !root.checkingSession
                            onTextChanged: {
                                root.username = text
                                root.message = ""
                            }
                            onAccepted: passwordField.forceActiveFocus()
                        }

                        Text {
                            Layout.topMargin: 4
                            text: qsTr("PASSPHRASE")
                            color: "#809295"
                            font.family: "Courier New"
                            font.pixelSize: 8
                            font.letterSpacing: 1.1
                        }

                        TextField {
                            id: passwordField
                            Layout.fillWidth: true
                            placeholderText: qsTr("Enter passphrase")
                            text: root.password
                            selectByMouse: true
                            enabled: !root.submitting && !root.checkingSession
                            echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                            onTextChanged: {
                                root.password = text
                                root.message = ""
                            }
                            onAccepted: root.authenticate()

                            ToolButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 38
                                height: parent.height
                                text: root.showPassword ? "\u25c9" : "\u25ce"
                                onClicked: root.showPassword = !root.showPassword
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        Layout.topMargin: 4
                        visible: !root.signedIn
                        text: root.message
                        color: "#ef8c86"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                    }

                    Button {
                        id: submitButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        text: root.signedIn
                              ? qsTr("SIGN OUT")
                              : root.submitting
                                ? qsTr("AUTHENTICATING")
                                : qsTr("AUTHENTICATE") + "    \u2192"
                        enabled: !root.submitting && !root.checkingSession
                        onClicked: root.signedIn ? root.signOut() : root.authenticate()

                        background: Rectangle {
                            color: root.signedIn
                                   ? (submitButton.hovered ? "#15303a" : "#0d222b")
                                   : (submitButton.hovered ? "#4cc2f7" : "#00a6f2")
                            border.color: root.signedIn ? "#315866" : "#4cc2f7"
                        }

                        contentItem: Text {
                            text: submitButton.text
                            color: root.signedIn ? "#b9d3dc" : "#041019"
                            font.family: "Courier New"
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 12
                        text: qsTr("TLS ENCRYPTED CONNECTION")
                        color: "#627679"
                        font.family: "Courier New"
                        font.pixelSize: 8
                        font.letterSpacing: 1.0
                    }
                }
            }

            Rectangle {
                Layout.columnSpan: root.width >= 820 ? 2 : 1
                Layout.fillWidth: true
                Layout.maximumWidth: 900
                Layout.preferredHeight: 420
                Layout.alignment: Qt.AlignHCenter
                visible: root.signedIn
                color: "#152130"
                border.width: 1
                border.color: "#263a4d"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 14

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width >= 780 ? 2 : 1
                        rowSpacing: 16
                        columnSpacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: qsTr("IMAGEWRITER PROFILES / %1").arg(accountName.toUpperCase())
                                color: "#00a6f2"
                                font.family: "Courier New"
                                font.pixelSize: 9
                                font.letterSpacing: 1.1
                            }

                            Text {
                                text: qsTr("OpenHD configuration library")
                                color: "#eff7f9"
                                font.pixelSize: 22
                                font.weight: Font.Medium
                            }

                            Text {
                                text: qsTr("Save OpenHD and QOpenHD settings, then apply them before choosing an image.")
                                color: "#718b96"
                                font.pixelSize: 11
                            }
                        }

                        Flow {
                            Layout.alignment: root.width >= 780 ? Qt.AlignRight | Qt.AlignTop : Qt.AlignLeft
                            Layout.fillWidth: root.width < 780
                            spacing: 8

                            Button {
                                text: qsTr("Refresh")
                                implicitHeight: 36
                                onClicked: root.loadProfiles()
                            }

                            Button {
                                text: qsTr("Save current settings")
                                implicitHeight: 36
                                onClicked: {
                                    profileNameField.text = ""
                                    profileDescriptionField.text = ""
                                    saveMessage.text = ""
                                    saveProfilePopup.open()
                                }
                            }

                            Button {
                                text: qsTr("Sign out")
                                implicitHeight: 36
                                onClicked: root.signOut()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#1d3945"
                    }

                    ListView {
                        id: profilesList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        model: profileModel

                        delegate: Rectangle {
                            width: profilesList.width
                            height: 76
                            color: "#152130"
                            border.color: "#263a4d"
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: 17
                                    color: "#112a3b"
                                    border.color: "#1c4a6b"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u2699"
                                        color: "#00a6f2"
                                        font.pixelSize: 16
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: profileName
                                        color: "#eaf4f7"
                                        font.pixelSize: 14
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: profileDescription.length > 0
                                              ? profileDescription
                                              : qsTr("OpenHD configuration profile")
                                        color: "#718b96"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }

                                Button {
                                    text: qsTr("Apply and write")
                                    onClicked: root.applyProfile(profileId,
                                                                 profileName,
                                                                 profileSettings,
                                                                 profileQOpenHDConfig)
                                }

                                ToolButton {
                                    text: "\u00d7"
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Delete profile")
                                    onClicked: root.deleteProfile(profileId)
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: profileModel.count === 0
                            text: root.loadingProfiles
                                  ? qsTr("Loading profiles...")
                                  : qsTr("No profiles yet. Save the current ImageWriter settings to create one.")
                            color: "#718b96"
                            font.pixelSize: 12
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.message
                        color: "#efaa72"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "OPENHD TECHNOLOGIES / FC-01"
                color: "#4d626a"
                font.family: "Courier New"
                font.pixelSize: 8
                font.letterSpacing: 1.0
            }

            Item { Layout.fillWidth: true }

            Button {
                flat: true
                text: qsTr("OPEN WEB PORTAL") + "  \u2197"
                onClicked: Qt.openUrlExternally(root.portalUrl)
                contentItem: Text {
                    text: parent.text
                    color: "#6daec7"
                    font.family: "Courier New"
                    font.pixelSize: 9
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    Popup {
        id: saveProfilePopup
        anchors.centerIn: parent
        width: Math.min(440, root.width - 40)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "#152130"
            border.color: "#263a4d"
            radius: 7
        }

        contentItem: ColumnLayout {
            spacing: 10

            Text {
                text: qsTr("Save FleetControl profile")
                color: "#eff7f9"
                font.pixelSize: 19
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("The current OpenHD settings and selected QOpenHD.conf will be stored in your account.")
                color: "#79929c"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            TextField {
                id: profileNameField
                Layout.fillWidth: true
                placeholderText: qsTr("Profile name")
                selectByMouse: true
            }

            TextField {
                id: profileDescriptionField
                Layout.fillWidth: true
                placeholderText: qsTr("Description (optional)")
                selectByMouse: true
                onAccepted: root.saveCurrentProfile()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Switch {
                    id: streamToPlatformSwitch
                    text: qsTr("Stream video to FleetControl platform")
                    checked: enabled
                    enabled: accountRole.toLowerCase() !== "developer" && accountRole.toLowerCase() !== "tester"
                    
                    contentItem: Text {
                        text: streamToPlatformSwitch.text
                        color: streamToPlatformSwitch.enabled ? "#eff7f9" : "#576a75"
                        font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: streamToPlatformSwitch.indicator.width + streamToPlatformSwitch.spacing
                    }
                }

                Text {
                    visible: !streamToPlatformSwitch.enabled
                    text: qsTr("Platform streaming is not available for Developer or Tester licenses.")
                    color: "#79929c"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.leftMargin: streamToPlatformSwitch.indicator.width + streamToPlatformSwitch.spacing
                }
            }

            Text {
                id: saveMessage
                Layout.fillWidth: true
                color: "#ef8c86"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Cancel")
                    flat: true
                    enabled: !root.savingProfile
                    onClicked: saveProfilePopup.close()
                }

                Button {
                    text: root.savingProfile ? qsTr("Saving...") : qsTr("Save profile")
                    enabled: !root.savingProfile
                    onClicked: root.saveCurrentProfile()
                }
            }
        }
    }
}
