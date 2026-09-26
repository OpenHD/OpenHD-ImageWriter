import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import "FleetProfilesHelper.js" as FleetProfilesHelper

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
    property bool loadingCrafts: false
    property int activeFilter: 0 // 0: My Fleet, 1: Air Vehicles, 2: Ground Stations, 3: Example Templates
    property string activeCraftName: imageWriter.getValue("fleetcontrol_craft_name") || ""

    // Settings map from OpenHD specification
    property var settingsMap: FleetProfilesHelper.getSettingsMap(imageWriter)
    property var editorVendors: []
    property string savedVendor: ""
    property string savedCamera: ""
    property string savedResolution: ""
    property string savedSecondaryCamera: ""
    property string savedSecondaryResolution: ""

    // Full-tab Unit Editor state
    property bool unitEditorVisible: false
    property int editIndex: -1
    property string editorSelectedCategory: "craft"
    property string editorSelectedIcon: "craft-quadcopter"
    property string editorSelectedHardware: "Raspberry Pi (4 / 5 / CM4 / Zero 2W)"
    property bool editorAdvancedOpen: false

    ListModel { id: craftModel }

    ListModel {
        id: templateModel

        ListElement {
            craftId: "tpl_recon_quad"
            craftName: "Recon Quad 7\""
            craftCategory: "craft"
            craftIcon: "craft-quadcopter"
            craftRole: "air"
            craftHardware: "Raspberry Pi (Pi 4 / Pi 5 / CM4 / Zero 2W)"
            craftDescription: "Long range FPV scout multirotor with HD digital link"
            craftCameraVendor: "Raspberry"
            craftCamera: "IMX708"
            craftCameraResolution: "1080p60"
            craftCameraPort: "cam0"
            craftCamera2: ""
            craftCamera2Resolution: ""
            craftCamera2Port: "cam1"
            craftIpCameraAddress: ""
            craftIpCameraPipeline: ""
            craftHotSpot: ""
            craftDisplayForceMode: false
            craftDisplayWidth: 1920
            craftDisplayHeight: 1080
            craftDisplayRefreshHz: 60
            craftMapboxApiKey: ""
        }
        ListElement {
            craftId: "tpl_skysurfer_wing"
            craftName: "SkySurfer Fixed Wing"
            craftCategory: "craft"
            craftIcon: "craft-plane"
            craftRole: "air"
            craftHardware: "Radxa Zero 3W / Rock 3 (RK3566)"
            craftDescription: "High-efficiency aerial surveying and long endurance flight"
            craftCameraVendor: "Zero3W"
            craftCamera: "IMX415"
            craftCameraResolution: "1080p60"
            craftCameraPort: "cam0"
            craftCamera2: ""
            craftCamera2Resolution: ""
            craftCamera2Port: "cam1"
            craftIpCameraAddress: ""
            craftIpCameraPipeline: ""
            craftHotSpot: ""
            craftDisplayForceMode: false
            craftDisplayWidth: 1920
            craftDisplayHeight: 1080
            craftDisplayRefreshHz: 60
            craftMapboxApiKey: ""
        }
        ListElement {
            craftId: "tpl_tactical_vtol"
            craftName: "VTOL Hybrid Scout"
            craftCategory: "craft"
            craftIcon: "craft-vtol"
            craftRole: "air"
            craftHardware: "OpenHD Core X20"
            craftDescription: "Vertical takeoff with transition to fixed-wing cruise"
            craftCameraVendor: "X20"
            craftCamera: "IMX415"
            craftCameraResolution: "1080p60"
            craftCameraPort: "cam0"
            craftCamera2: ""
            craftCamera2Resolution: ""
            craftCamera2Port: "cam1"
            craftIpCameraAddress: ""
            craftIpCameraPipeline: ""
            craftHotSpot: ""
            craftDisplayForceMode: false
            craftDisplayWidth: 1920
            craftDisplayHeight: 1080
            craftDisplayRefreshHz: 60
            craftMapboxApiKey: ""
        }
        ListElement {
            craftId: "tpl_heavy_hexacopter"
            craftName: "Heavy Lifter Hexacopter"
            craftCategory: "craft"
            craftIcon: "craft-hexacopter"
            craftRole: "air"
            craftHardware: "Raspberry Pi (Pi 4 / Pi 5 / CM4 / Zero 2W)"
            craftDescription: "Payload carrier with redundant propulsion and multi-camera support"
            craftCameraVendor: "Raspberry"
            craftCamera: "IMX477"
            craftCameraResolution: "1080p60"
            craftCameraPort: "cam0"
            craftCamera2: "IMX708"
            craftCamera2Resolution: "720p60"
            craftCamera2Port: "cam1"
            craftIpCameraAddress: ""
            craftIpCameraPipeline: ""
            craftHotSpot: ""
            craftDisplayForceMode: false
            craftDisplayWidth: 1920
            craftDisplayHeight: 1080
            craftDisplayRefreshHz: 60
            craftMapboxApiKey: ""
        }
        ListElement {
            craftId: "tpl_rover_ugv"
            craftName: "Ground Rover UGV"
            craftCategory: "craft"
            craftIcon: "craft-rover"
            craftRole: "air"
            craftHardware: "Radxa Zero 3W / Rock 3 (RK3566)"
            craftDescription: "Unmanned ground vehicle rover with network IP camera"
            craftCameraVendor: "Network"
            craftCamera: "IP-CAMERA"
            craftCameraResolution: "1080p30"
            craftCameraPort: "cam0"
            craftCamera2: ""
            craftCamera2Resolution: ""
            craftCamera2Port: "cam1"
            craftIpCameraAddress: "192.168.144.108"
            craftIpCameraPipeline: "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
            craftHotSpot: ""
            craftDisplayForceMode: false
            craftDisplayWidth: 1920
            craftDisplayHeight: 1080
            craftDisplayRefreshHz: 60
            craftMapboxApiKey: ""
        }
        ListElement {
            craftId: "tpl_tactical_gcs"
            craftName: "Dual-Screen Tactical GCS"
            craftCategory: "station"
            craftIcon: "station-military-gcs"
            craftRole: "ground"
            craftHardware: "PC / x86_64 Ground Station"
            craftDescription: "Industrial field control station with dual tactical screens"
            craftCameraVendor: ""
            craftCamera: ""
            craftCameraResolution: ""
            craftCameraPort: "cam0"
            craftCamera2: ""
            craftCamera2Resolution: ""
            craftCamera2Port: "cam1"
            craftIpCameraAddress: ""
            craftIpCameraPipeline: ""
            craftHotSpot: "openhd_gcs_secure"
            craftDisplayForceMode: true
            craftDisplayWidth: 1920
            craftDisplayHeight: 1080
            craftDisplayRefreshHz: 60
            craftMapboxApiKey: ""
        }
        ListElement {
            craftId: "tpl_goggles_fpv"
            craftName: "HD FPV Goggles"
            craftCategory: "station"
            craftIcon: "station-goggles"
            craftRole: "ground"
            craftHardware: "Radxa Zero 3W / Rock 3 (RK3566)"
            craftDescription: "Pilot low-latency visual immersion display"
            craftCameraVendor: ""
            craftCamera: ""
            craftCameraResolution: ""
            craftCameraPort: "cam0"
            craftCamera2: ""
            craftCamera2Resolution: ""
            craftCamera2Port: "cam1"
            craftIpCameraAddress: ""
            craftIpCameraPipeline: ""
            craftHotSpot: ""
            craftDisplayForceMode: true
            craftDisplayWidth: 1280
            craftDisplayHeight: 720
            craftDisplayRefreshHz: 60
            craftMapboxApiKey: ""
        }
        ListElement {
            craftId: "tpl_tracker_station"
            craftName: "Antenna Tracker Unit"
            craftCategory: "station"
            craftIcon: "station-tracker"
            craftRole: "ground"
            craftHardware: "Raspberry Pi (Pi 4 / Pi 5 / CM4 / Zero 2W)"
            craftDescription: "Automated 360-degree directional tracking station"
            craftCameraVendor: ""
            craftCamera: ""
            craftCameraResolution: ""
            craftCameraPort: "cam0"
            craftCamera2: ""
            craftCamera2Resolution: ""
            craftCamera2Port: "cam1"
            craftIpCameraAddress: ""
            craftIpCameraPipeline: ""
            craftHotSpot: ""
            craftDisplayForceMode: false
            craftDisplayWidth: 1920
            craftDisplayHeight: 1080
            craftDisplayRefreshHz: 60
            craftMapboxApiKey: ""
        }
        ListElement {
            craftId: "tpl_rc_controller"
            craftName: "Field RC Transmitter"
            craftCategory: "station"
            craftIcon: "station-transmitter"
            craftRole: "ground"
            craftHardware: "Radxa Zero 3W / Rock 3 (RK3566)"
            craftDescription: "Handheld telemetry and telemetry control unit"
            craftCameraVendor: ""
            craftCamera: ""
            craftCameraResolution: ""
            craftCameraPort: "cam0"
            craftCamera2: ""
            craftCamera2Resolution: ""
            craftCamera2Port: "cam1"
            craftIpCameraAddress: ""
            craftIpCameraPipeline: ""
            craftHotSpot: ""
            craftDisplayForceMode: false
            craftDisplayWidth: 800
            craftDisplayHeight: 480
            craftDisplayRefreshHz: 60
            craftMapboxApiKey: ""
        }
    }

    function iconSource(key) {
        var map = {
            "craft-quadcopter": "../icons/ui/craft-quadcopter.svg",
            "craft-plane": "../icons/ui/craft-plane.svg",
            "craft-vtol": "../icons/ui/craft-vtol.svg",
            "craft-hexacopter": "../icons/ui/craft-hexacopter.svg",
            "craft-rover": "../icons/ui/craft-rover.svg",
            "station-goggles": "../icons/ui/station-goggles.svg",
            "station-tracker": "../icons/ui/station-tracker.svg",
            "station-transmitter": "../icons/ui/station-transmitter.svg",
            "station-military-gcs": "../icons/ui/station-military-gcs.svg"
        }
        return map[key] || "../icons/ui/hub.svg"
    }

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

    function parseResponse(xhr) {
        try {
            return JSON.parse(xhr.responseText)
        } catch (error) {
            return ({})
        }
    }

    function getCacheKey() {
        return "fleetcontrol_crafts_" + (accountName && accountName.length > 0 ? accountName.toLowerCase() : "default")
    }

    function saveCraftsLocally() {
        var list = []
        for (var i = 0; i < craftModel.count; ++i) {
            var item = craftModel.get(i)
            list.push({
                "id": item.craftId,
                "name": item.craftName,
                "category": item.craftCategory,
                "icon": item.craftIcon,
                "role": item.craftRole,
                "hardware": item.craftHardware,
                "description": item.craftDescription,
                "cameraVendor": item.craftCameraVendor || "",
                "camera": item.craftCamera || "",
                "cameraResolution": item.craftCameraResolution || "",
                "cameraPort": item.craftCameraPort || "cam0",
                "camera2": item.craftCamera2 || "",
                "camera2Resolution": item.craftCamera2Resolution || "",
                "camera2Port": item.craftCamera2Port || "cam1",
                "ipCameraAddress": item.craftIpCameraAddress || "",
                "ipCameraPipeline": item.craftIpCameraPipeline || "",
                "camera2IpAddress": item.craftCamera2IpAddress || "",
                "camera2IpPipeline": item.craftCamera2IpPipeline || "",
                "hotSpot": item.craftHotSpot || "",
                "displayForceMode": item.craftDisplayForceMode || false,
                "displayWidth": item.craftDisplayWidth || 1920,
                "displayHeight": item.craftDisplayHeight || 1080,
                "displayRefreshHz": item.craftDisplayRefreshHz || 60,
                "mapboxApiKey": item.craftMapboxApiKey || ""
            })
        }
        imageWriter.setSetting(getCacheKey(), JSON.stringify(list))
    }

    function sbcKeyFromHardware(hw) {
        return FleetProfilesHelper.sbcKeyFromHardware(hw)
    }

    function loadCrafts() {
        loadingCrafts = true
        message = ""
        activeCraftName = imageWriter.getValue("fleetcontrol_craft_name") || ""

        // Fast load cached account profile data
        var localData = imageWriter.getValue(getCacheKey())
        if (localData && localData.length > 5) {
            try {
                var parsed = JSON.parse(localData)
                if (parsed && Array.isArray(parsed)) {
                    craftModel.clear()
                    for (var j = 0; j < parsed.length; ++j) {
                        var p = parsed[j]
                        craftModel.append({
                            "craftId": p.id || ("craft_" + j),
                            "craftName": p.name || "",
                            "craftCategory": p.category || "craft",
                            "craftIcon": p.icon || (p.category === "station" ? "station-military-gcs" : "craft-quadcopter"),
                            "craftRole": p.role || (p.category === "station" ? "ground" : "air"),
                            "craftHardware": p.hardware || "Raspberry Pi (Pi 4 / Pi 5 / CM4 / Zero 2W)",
                            "craftDescription": p.description || "",
                            "craftCameraVendor": p.cameraVendor || "",
                            "craftCamera": p.camera || "",
                            "craftCameraResolution": p.cameraResolution || "",
                            "craftCameraPort": p.cameraPort || "cam0",
                            "craftCamera2": p.camera2 || "",
                            "craftCamera2Resolution": p.camera2Resolution || "",
                            "craftCamera2Port": p.camera2Port || "cam1",
                            "craftIpCameraAddress": p.ipCameraAddress || "",
                            "craftIpCameraPipeline": p.ipCameraPipeline || "",
                            "craftCamera2IpAddress": p.camera2IpAddress || "",
                            "craftCamera2IpPipeline": p.camera2IpPipeline || "",
                            "craftHotSpot": p.hotSpot || "",
                            "craftDisplayForceMode": p.displayForceMode || false,
                            "craftDisplayWidth": p.displayWidth || 1920,
                            "craftDisplayHeight": p.displayHeight || 1080,
                            "craftDisplayRefreshHz": p.displayRefreshHz || 60,
                            "craftMapboxApiKey": p.mapboxApiKey || ""
                        })
                    }
                }
            } catch (e) {
                // fall through
            }
        }

        // Sync with FleetControl account profiles
        request("GET", "/api/imagewriter/profiles", undefined, function(xhr, response) {
            loadingCrafts = false
            if (xhr.status >= 200 && xhr.status < 300 && response.profiles) {
                craftModel.clear()
                for (var i = 0; i < response.profiles.length; ++i) {
                    var profile = response.profiles[i]
                    var s = profile.openhdSettings || {}
                    var role = s.mode || "air"
                    var isStation = (profile.name || "").toLowerCase().indexOf("station") >= 0 ||
                                    (profile.name || "").toLowerCase().indexOf("gcs") >= 0 ||
                                    (profile.name || "").toLowerCase().indexOf("goggle") >= 0 ||
                                    role === "ground"
                    var category = s.craftCategory || (isStation ? "station" : "craft")
                    var icon = s.craftIcon || (category === "station" ? "station-military-gcs" : "craft-quadcopter")
                    var hardware = s.craftHardware || s.sbc || "Raspberry Pi (Pi 4 / Pi 5 / CM4 / Zero 2W)"

                    craftModel.append({
                        "craftId": profile.id || ("craft_" + i),
                        "craftName": profile.name || "",
                        "craftCategory": category,
                        "craftIcon": icon,
                        "craftRole": role,
                        "craftHardware": hardware,
                        "craftDescription": profile.description || "",
                        "craftCameraVendor": s.cameraVendor || s.craftCameraVendor || "",
                        "craftCamera": s.camera || "",
                        "craftCameraResolution": s.cameraResolution || "",
                        "craftCameraPort": s.cameraPort || "cam0",
                        "craftCamera2": s.camera2 || "",
                        "craftCamera2Resolution": s.camera2Resolution || "",
                        "craftCamera2Port": s.camera2Port || "cam1",
                        "craftIpCameraAddress": s.ipCameraAddress || "",
                        "craftIpCameraPipeline": s.ipCameraPipeline || "",
                        "craftCamera2IpAddress": s.camera2IpAddress || "",
                        "craftCamera2IpPipeline": s.camera2IpPipeline || "",
                        "craftHotSpot": s.hotSpot || "",
                        "craftDisplayForceMode": s.displayForceMode || false,
                        "craftDisplayWidth": s.displayWidth || 1920,
                        "craftDisplayHeight": s.displayHeight || 1080,
                        "craftDisplayRefreshHz": s.displayRefreshHz || 60,
                        "craftMapboxApiKey": s.mapboxApiKey || ""
                    })
                }
                saveCraftsLocally()
            }
        })
    }

    function saveCraft(name, category, icon, hardware, description, advancedOptions, editIdx) {
        var role = category === "craft" ? "air" : "ground"
        var tempId = (editIdx >= 0 && editIdx < craftModel.count)
                     ? craftModel.get(editIdx).craftId
                     : ("craft_" + Date.now())
        var sbcKey = sbcKeyFromHardware(hardware)

        var craftObj = {
            "craftId": tempId,
            "craftName": name,
            "craftCategory": category,
            "craftIcon": icon,
            "craftRole": role,
            "craftHardware": hardware,
            "craftDescription": description,
            "craftCameraVendor": advancedOptions.cameraVendor || "",
            "craftCamera": advancedOptions.camera || "",
            "craftCameraResolution": advancedOptions.cameraResolution || "",
            "craftCameraPort": advancedOptions.cameraPort || "cam0",
            "craftCamera2": advancedOptions.camera2 || "",
            "craftCamera2Resolution": advancedOptions.camera2Resolution || "",
            "craftCamera2Port": advancedOptions.camera2Port || "cam1",
            "craftIpCameraAddress": advancedOptions.ipCameraAddress || "",
            "craftIpCameraPipeline": advancedOptions.ipCameraPipeline || "",
            "craftCamera2IpAddress": advancedOptions.camera2IpAddress || "",
            "craftCamera2IpPipeline": advancedOptions.camera2IpPipeline || "",
            "craftHotSpot": advancedOptions.hotSpot || "",
            "craftDisplayForceMode": category === "station" ? (advancedOptions.displayForceMode || false) : false,
            "craftDisplayWidth": advancedOptions.displayWidth || 1920,
            "craftDisplayHeight": advancedOptions.displayHeight || 1080,
            "craftDisplayRefreshHz": advancedOptions.displayRefreshHz || 60,
            "craftMapboxApiKey": category === "station" ? (advancedOptions.mapboxApiKey || "") : ""
        }

        if (editIdx >= 0 && editIdx < craftModel.count) {
            for (var prop in craftObj) {
                craftModel.setProperty(editIdx, prop, craftObj[prop])
            }
            message = qsTr("Updated '%1' in your fleet.").arg(name)
        } else {
            craftModel.append(craftObj)
            message = qsTr("Created '%1' in your fleet.").arg(name)
        }
        saveCraftsLocally()

        var payload = {
            "name": name,
            "description": description,
            "openhdSettings": {
                "mode": role,
                "sbc": sbcKey,
                "craftCategory": category,
                "craftIcon": icon,
                "craftHardware": hardware,
                "cameraVendor": craftObj.craftCameraVendor,
                "camera": craftObj.craftCamera,
                "cameraResolution": craftObj.craftCameraResolution,
                "cameraPort": craftObj.craftCameraPort,
                "camera2": craftObj.craftCamera2,
                "camera2Resolution": craftObj.craftCamera2Resolution,
                "camera2Port": craftObj.craftCamera2Port,
                "ipCameraAddress": craftObj.craftIpCameraAddress,
                "ipCameraPipeline": craftObj.craftIpCameraPipeline,
                "camera2IpAddress": craftObj.craftCamera2IpAddress,
                "camera2IpPipeline": craftObj.craftCamera2IpPipeline,
                "hotSpot": craftObj.craftHotSpot,
                "displayForceMode": craftObj.craftDisplayForceMode,
                "displayWidth": craftObj.craftDisplayWidth,
                "displayHeight": craftObj.craftDisplayHeight,
                "displayRefreshHz": craftObj.craftDisplayRefreshHz,
                "mapboxApiKey": craftObj.craftMapboxApiKey
            }
        }

        request("POST", "/api/imagewriter/profiles", payload, function(xhr, resp) {
            if (xhr.status >= 200 && xhr.status < 300 && resp && resp.profile && resp.profile.id) {
                for (var k = 0; k < craftModel.count; ++k) {
                    if (craftModel.get(k).craftId === tempId) {
                        craftModel.setProperty(k, "craftId", resp.profile.id)
                        break
                    }
                }
                saveCraftsLocally()
                message = qsTr("Synced '%1' to FleetControl account.").arg(name)
            }
        })
    }

    function deleteCraft(index) {
        if (index >= 0 && index < craftModel.count) {
            var item = craftModel.get(index)
            var craftId = item.craftId
            var craftName = item.craftName
            craftModel.remove(index)
            saveCraftsLocally()
            message = qsTr("Removed '%1' from fleet.").arg(craftName)

            if (craftId && String(craftId).indexOf("craft_") !== 0) {
                request("DELETE", "/api/imagewriter/profiles/" + encodeURIComponent(craftId), undefined, function(xhr, resp) {
                    // Removed on cloud
                })
            }
        }
    }

    function importTemplate(tpl) {
        var adv = {
            "cameraVendor": tpl.craftCameraVendor || "",
            "camera": tpl.craftCamera || "",
            "cameraResolution": tpl.craftCameraResolution || "",
            "cameraPort": tpl.craftCameraPort || "cam0",
            "camera2": tpl.craftCamera2 || "",
            "camera2Resolution": tpl.craftCamera2Resolution || "",
            "camera2Port": tpl.craftCamera2Port || "cam1",
            "ipCameraAddress": tpl.craftIpCameraAddress || "",
            "ipCameraPipeline": tpl.craftIpCameraPipeline || "",
            "camera2IpAddress": tpl.craftCamera2IpAddress || "",
            "camera2IpPipeline": tpl.craftCamera2IpPipeline || "",
            "hotSpot": tpl.craftHotSpot || "",
            "displayForceMode": tpl.craftDisplayForceMode || false,
            "displayWidth": tpl.craftDisplayWidth || 1920,
            "displayHeight": tpl.craftDisplayHeight || 1080,
            "displayRefreshHz": tpl.craftDisplayRefreshHz || 60,
            "mapboxApiKey": tpl.craftCategory === "station" ? (tpl.craftMapboxApiKey || "") : ""
        }
        saveCraft(tpl.craftName, tpl.craftCategory, tpl.craftIcon, tpl.craftHardware, tpl.craftDescription, adv, -1)
        activeFilter = 0
        message = qsTr("Preset '%1' added to your FleetControl account.").arg(tpl.craftName)
    }

    function selectAndFlashCraft(craft) {
        FleetProfilesHelper.applyProfile(imageWriter, craft)
        activeCraftName = craft.craftName
        var role = craft.craftRole || (craft.craftCategory === "station" ? "ground" : "air")
        message = qsTr("Configured for %1 (%2). Choose an image to continue.").arg(craft.craftName).arg(role.toUpperCase())
        if (mainWindow && mainWindow.writeWithFleetControlProfile)
    }

    function clearActiveCraft() {
        imageWriter.setSetting("fleetcontrol_craft_id", "")
        imageWriter.setSetting("fleetcontrol_craft_name", "")
        activeCraftName = ""
        message = qsTr("Craft selection cleared. Flashing will proceed with default standalone settings.")
    }

    function skipToStandaloneFlash() {
        clearActiveCraft()
        if (mainWindow && mainWindow.openFeature)
            mainWindow.openFeature("flash")
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
                if (mainWindow && mainWindow.setFleetControlSignedIn)
                    mainWindow.setFleetControlSignedIn(true)
                loadCrafts()
            } else {
                var savedUser = imageWriter.getValue("fleetcontrol_username")
                var savedPass = imageWriter.getValue("fleetcontrol_password")
                if (savedUser && savedPass) {
                    username = savedUser
                    password = savedPass
                    authenticate()
                } else if (mainWindow && mainWindow.setFleetControlSignedIn)
                    mainWindow.setFleetControlSignedIn(false)
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
                if (mainWindow && mainWindow.setFleetControlSignedIn)
                    mainWindow.setFleetControlSignedIn(true)
                message = ""
                imageWriter.setSetting("fleetcontrol_username", currentUsername)
                imageWriter.setSetting("fleetcontrol_password", passToSave)
                loadCrafts()
            } else if (xhr.status === 0) {
                if (mainWindow && mainWindow.setFleetControlSignedIn)
                    mainWindow.setFleetControlSignedIn(false)
                message = qsTr("Unable to reach the secure FleetControl gateway.")
            } else {
                if (mainWindow && mainWindow.setFleetControlSignedIn)
                    mainWindow.setFleetControlSignedIn(false)
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
                craftModel.clear()
                unitEditorVisible = false
                if (mainWindow && mainWindow.setFleetControlSignedIn)
                    mainWindow.setFleetControlSignedIn(false)
            }
        }
        xhr.open("POST", apiBaseUrl + "/api/logout")
        xhr.timeout = 10000
        xhr.send()
    }

    // Full-Tab Unit Editor Functions
    function refreshEditorVendors(preserveSaved) {
        if (!settingsMap) {
            settingsMap = FleetProfilesHelper.getSettingsMap(imageWriter)
        }
        var sbcKey = FleetProfilesHelper.sbcKeyFromHardware(root.editorSelectedHardware)
        var vendors = FleetProfilesHelper.getVendorsForSbc(settingsMap, sbcKey)
        editorVendors = vendors

        var vendorNames = []
        for (var i = 0; i < vendors.length; i++) {
            vendorNames.push(vendors[i].displayName || vendors[i].id)
        }
        vendorDropdown.model = vendorNames

        var targetVendorIndex = 0
        if (preserveSaved && savedVendor && savedVendor.length > 0) {
            for (var v = 0; v < vendors.length; v++) {
                if (vendors[v].displayName === savedVendor || vendors[v].id === savedVendor) {
                    targetVendorIndex = v
                    break
                }
            }
        } else if (preserveSaved && savedCamera && savedCamera.length > 0) {
            for (var v2 = 0; v2 < vendors.length; v2++) {
                var vOpts = vendors[v2].options || []
                for (var o = 0; o < vOpts.length; o++) {
                    if (vOpts[o].id === savedCamera) {
                        targetVendorIndex = v2
                        break
                    }
                }
            }
        }
        vendorDropdown.currentIndex = (vendorNames.length > 0) ? targetVendorIndex : -1
        refreshEditorCameras(preserveSaved)
    }

    function refreshEditorCameras(preserveSaved) {
        var vendor = (editorVendors && vendorDropdown.currentIndex >= 0 && vendorDropdown.currentIndex < editorVendors.length)
                     ? editorVendors[vendorDropdown.currentIndex] : null

        var camNames = ["NONE"]
        if (vendor && vendor.options) {
            for (var i = 0; i < vendor.options.length; i++) {
                camNames.push(vendor.options[i].id)
            }
        }
        cameraDropdown.model = camNames

        var targetCamIndex = 0
        var targetCamName = preserveSaved ? savedCamera : ""
        if (targetCamName && targetCamName.length > 0) {
            for (var c = 0; c < camNames.length; c++) {
                if (camNames[c] === targetCamName) {
                    targetCamIndex = c
                    break
                }
            }
        }
        cameraDropdown.currentIndex = (camNames.length > 0) ? targetCamIndex : -1

        refreshEditorSecondaryCameras(preserveSaved)
        refreshEditorResolutions(preserveSaved)
    }

    function refreshEditorResolutions(preserveSaved) {
        var sbcKey = FleetProfilesHelper.sbcKeyFromHardware(root.editorSelectedHardware)
        var vendor = (editorVendors && vendorDropdown.currentIndex >= 0 && vendorDropdown.currentIndex < editorVendors.length)
                     ? editorVendors[vendorDropdown.currentIndex] : null
        var vendorId = vendor ? vendor.id : ""
        var selectedCam = (cameraDropdown.currentIndex >= 0 && cameraDropdown.currentIndex < cameraDropdown.model.length)
                          ? cameraDropdown.model[cameraDropdown.currentIndex] : ""

        var resolutions = FleetProfilesHelper.getResolutionsForCamera(settingsMap, sbcKey, vendorId, selectedCam)
        var filtered = []
        var seen = {}
        for (var i = 0; i < resolutions.length; i++) {
            var r = resolutions[i]
            if (r !== "0x0@0" && !seen[r]) {
                seen[r] = true
                filtered.push(r)
            }
        }
        if (filtered.length === 0 && selectedCam !== "NONE" && selectedCam.length > 0) {
            filtered = ["1080p60", "720p60", "1080p30"]
        }
        resDropdown.model = filtered

        var targetResIndex = 0
        var targetRes = preserveSaved ? savedResolution : ""
        if (targetRes && targetRes.length > 0) {
            for (var idx = 0; idx < filtered.length; idx++) {
                if (filtered[idx] === targetRes) {
                    targetResIndex = idx
                    break
                }
            }
        }
        resDropdown.currentIndex = (filtered.length > 0) ? targetResIndex : -1
    }

    function refreshEditorSecondaryCameras(preserveSaved) {
        var sbcKey = FleetProfilesHelper.sbcKeyFromHardware(root.editorSelectedHardware)
        var secOpts = FleetProfilesHelper.getSecondaryCameraOptions(settingsMap, sbcKey)
        var secNames = []
        for (var i = 0; i < secOpts.length; i++) {
            secNames.push(secOpts[i].displayName || secOpts[i].id)
        }
        camera2Dropdown.model = secNames

        var targetSecIndex = 0
        var targetSec = preserveSaved ? savedSecondaryCamera : ""
        if (targetSec && targetSec.length > 0) {
            for (var s = 0; s < secOpts.length; s++) {
                if (secOpts[s].id === targetSec || secNames[s] === targetSec || ("CSI - " + secOpts[s].id) === targetSec) {
                    targetSecIndex = s
                    break
                }
            }
        }
        camera2Dropdown.currentIndex = (secNames.length > 0) ? targetSecIndex : -1
        refreshEditorSecondaryResolutions(preserveSaved)
    }

    function refreshEditorSecondaryResolutions(preserveSaved) {
        var sbcKey = FleetProfilesHelper.sbcKeyFromHardware(root.editorSelectedHardware)
        var secOpts = FleetProfilesHelper.getSecondaryCameraOptions(settingsMap, sbcKey)
        var selectedSecId = (camera2Dropdown.currentIndex >= 0 && camera2Dropdown.currentIndex < secOpts.length)
                            ? secOpts[camera2Dropdown.currentIndex].id : ""

        var resolutions = FleetProfilesHelper.getResolutionsForSecondaryCamera(settingsMap, sbcKey, selectedSecId)
        var filtered = []
        var seen = {}
        for (var i = 0; i < resolutions.length; i++) {
            var r = resolutions[i]
            if (r !== "0x0@0" && !seen[r]) {
                seen[r] = true
                filtered.push(r)
            }
        }
        if (filtered.length === 0 && selectedSecId.length > 0) {
            filtered = ["1080p60", "720p60", "1080p30"]
        }
        res2Dropdown.model = filtered

        var targetResIndex = 0
        var targetRes = preserveSaved ? savedSecondaryResolution : ""
        if (targetRes && targetRes.length > 0) {
            for (var idx = 0; idx < filtered.length; idx++) {
                if (filtered[idx] === targetRes) {
                    targetResIndex = idx
                    break
                }
            }
        }
        res2Dropdown.currentIndex = (filtered.length > 0) ? targetResIndex : -1
    }

    function openNewUnitEditor() {
        editIndex = -1
        editorSelectedCategory = "craft"
        editorSelectedIcon = "craft-quadcopter"
        editorSelectedHardware = "Raspberry Pi (Pi 4 / Pi 5 / CM4 / Zero 2W)"
        craftNameField.text = ""
        craftDescField.text = ""
        hardwareDropdown.currentIndex = 0
        editorAdvancedOpen = false

        savedVendor = "Raspberry"
        savedCamera = "IMX708"
        savedResolution = "1080p60"
        savedSecondaryCamera = ""
        savedSecondaryResolution = ""
        editorCameraPort = "cam0"
        editorCamera2Port = "cam1"
        primaryPortDropdown.currentIndex = 0
        secondaryPortDropdown.currentIndex = 1
        ipCamAddressField.text = "192.168.144.108"
        ipCamPipelineField.text = "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
        camera2IpAddressField.text = "192.168.144.108"
        camera2IpPipelineField.text = "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"

        hotspotField.text = ""
        displayForceSwitch.checked = false
        displayWidthField.text = "1920"
        displayHeightField.text = "1080"
        displayFpsField.text = "60"
        mapboxKeyField.text = ""

        refreshEditorVendors(true)
        unitEditorVisible = true
    }

    function openEditUnitEditor(index) {
        if (index < 0 || index >= craftModel.count) return
        var craft = craftModel.get(index)
        editIndex = index
        editorSelectedCategory = craft.craftCategory || "craft"
        editorSelectedIcon = craft.craftIcon || (editorSelectedCategory === "craft" ? "craft-quadcopter" : "station-military-gcs")
        editorSelectedHardware = craft.craftHardware || "Raspberry Pi (Pi 4 / Pi 5 / CM4 / Zero 2W)"
        craftNameField.text = craft.craftName || ""
        craftDescField.text = craft.craftDescription || ""

        var hwIdx = 0
        for (var h = 0; h < hardwareDropdown.model.length; ++h) {
            if (hardwareDropdown.model[h] === editorSelectedHardware ||
                hardwareDropdown.model[h].indexOf(editorSelectedHardware) >= 0 ||
                editorSelectedHardware.indexOf(hardwareDropdown.model[h]) >= 0) {
                hwIdx = h
                break
            }
        }
        hardwareDropdown.currentIndex = hwIdx

        savedVendor = craft.craftCameraVendor || ""
        savedCamera = craft.craftCamera || ""
        savedResolution = craft.craftCameraResolution || ""
        savedSecondaryCamera = craft.craftCamera2 || ""
        savedSecondaryResolution = craft.craftCamera2Resolution || ""
        editorCameraPort = craft.craftCameraPort || "cam0"
        editorCamera2Port = craft.craftCamera2Port || "cam1"
        primaryPortDropdown.currentIndex = (editorCameraPort === "cam1" ? 1 : 0)
        secondaryPortDropdown.currentIndex = (editorCamera2Port === "cam0" ? 0 : 1)

        ipCamAddressField.text = craft.craftIpCameraAddress || "192.168.144.108"
        ipCamPipelineField.text = craft.craftIpCameraPipeline || "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
        camera2IpAddressField.text = craft.craftCamera2IpAddress || "192.168.144.108"
        camera2IpPipelineField.text = craft.craftCamera2IpPipeline || "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"

        hotspotField.text = craft.craftHotSpot || ""
        displayForceSwitch.checked = craft.craftDisplayForceMode || false
        displayWidthField.text = String(craft.craftDisplayWidth || 1920)
        displayHeightField.text = String(craft.craftDisplayHeight || 1080)
        displayFpsField.text = String(craft.craftDisplayRefreshHz || 60)
        mapboxKeyField.text = craft.craftMapboxApiKey || ""

        refreshEditorVendors(true)
        unitEditorVisible = true
    }

    function closeEditor() {
        unitEditorVisible = false
        editIndex = -1
    }

    function collectAndSaveEditor() {
        var name = craftNameField.text.trim()
        if (name.length === 0)
            name = editorSelectedCategory === "craft" ? qsTr("New Air Craft") : qsTr("New Ground Station")

        var selectedCam = (cameraDropdown.currentIndex >= 0 && cameraDropdown.currentIndex < cameraDropdown.model.length)
                          ? cameraDropdown.model[cameraDropdown.currentIndex] : ""
        if (selectedCam === "NONE") selectedCam = ""

        var selectedVendorName = (vendorDropdown.currentIndex >= 0 && vendorDropdown.currentIndex < vendorDropdown.model.length)
                                 ? vendorDropdown.model[vendorDropdown.currentIndex] : ""

        var secOpts = FleetProfilesHelper.getSecondaryCameraOptions(settingsMap, FleetProfilesHelper.sbcKeyFromHardware(editorSelectedHardware))
        var selectedSecId = (camera2Dropdown.currentIndex >= 0 && camera2Dropdown.currentIndex < secOpts.length)
                            ? secOpts[camera2Dropdown.currentIndex].id : ""

        var adv = {
            "cameraVendor": selectedVendorName,
            "camera": selectedCam,
            "cameraResolution": (resDropdown.currentIndex >= 0 && resDropdown.currentIndex < resDropdown.model.length)
                                ? resDropdown.model[resDropdown.currentIndex] : (resDropdown.currentText || ""),
            "cameraPort": primaryPortDropdown.currentIndex === 0 ? "cam0" : "cam1",
            "camera2": selectedSecId,
            "camera2Resolution": (res2Dropdown.currentIndex >= 0 && res2Dropdown.currentIndex < res2Dropdown.model.length)
                                 ? res2Dropdown.model[res2Dropdown.currentIndex] : (res2Dropdown.currentText || ""),
            "camera2Port": secondaryPortDropdown.currentIndex === 0 ? "cam0" : "cam1",
            "ipCameraAddress": ipCamAddressField.text.trim(),
            "ipCameraPipeline": ipCamPipelineField.text.trim(),
            "camera2IpAddress": camera2IpAddressField.text.trim(),
            "camera2IpPipeline": camera2IpPipelineField.text.trim(),
            "hotSpot": hotspotField.text.trim(),
            "displayForceMode": displayForceSwitch.checked,
            "displayWidth": parseInt(displayWidthField.text) || 1920,
            "displayHeight": parseInt(displayHeightField.text) || 1080,
            "displayRefreshHz": parseInt(displayFpsField.text) || 60,
            "mapboxApiKey": editorSelectedCategory === "station" ? mapboxKeyField.text.trim() : ""
        }

        root.saveCraft(name, editorSelectedCategory, editorSelectedIcon, editorSelectedHardware, craftDescField.text.trim(), adv, editIndex)
        closeEditor()
    }

    Component.onCompleted: {
        settingsMap = FleetProfilesHelper.getSettingsMap(imageWriter)
        checkSession()
    }

    Rectangle {
        anchors.fill: parent
        color: "#0d1b26"
    }

    // ==========================================
    // 1. FLEET OVERVIEW VIEW (When not in editor)
    // ==========================================
    Item {
        id: fleetOverview
        anchors.fill: parent
        visible: !root.unitEditorVisible

        Column {
            anchors.fill: parent
            anchors.margins: root.width < 700 ? 14 : 28
            spacing: 12

            // Top Gateway Bar (Responsive RowLayout)
            RowLayout {
                width: parent.width
                spacing: 12

                Row {
                    spacing: 10
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        width: 34
                        height: 34
                        source: "../icons/ui/hub.svg"
                        fillMode: Image.PreserveAspectFit
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: 0
                        anchors.verticalCenter: parent.verticalCenter
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
                }

                Item {
                    Layout.fillWidth: true
                }

                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: checkingSession ? "#607784" : (root.signedIn ? "#00e5a3" : "#00a6f2")
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: checkingSession
                              ? qsTr("CHECKING GATEWAY")
                              : (root.signedIn ? qsTr("OPERATOR AUTHENTICATED") : qsTr("SECURE GATEWAY ONLINE"))
                        color: "#82979f"
                        font.family: "Courier New"
                        font.pixelSize: 9
                        font.letterSpacing: 1.1
                    }
                }
            }

            // SIGNED OUT VIEW
            Rectangle {
                visible: !root.signedIn
                width: Math.min(parent.width - 24, 460)
                height: 440
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#152130"
                border.width: 1
                border.color: "#263a4d"
                radius: 8

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 11

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44
                        height: 44
                        radius: 22
                        color: "#112a3b"
                        border.color: "#1c4a6b"

                        Text {
                            anchors.centerIn: parent
                            text: "▣"
                            color: "#00a6f2"
                            font.pixelSize: 20
                            font.bold: true
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("AUTHORIZED PERSONNEL")
                        color: "#71878b"
                        font.family: "Courier New"
                        font.pixelSize: 8
                        font.letterSpacing: 1.4
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("FleetControl Sign In")
                        color: "#eff7f9"
                        font.pixelSize: 19
                        font.weight: Font.Medium
                    }

                    Text {
                        text: qsTr("OPERATOR ID")
                        color: "#809295"
                        font.family: "Courier New"
                        font.pixelSize: 8
                    }

                    TextField {
                        id: usernameField
                        width: parent.width
                        placeholderText: qsTr("Enter operator ID")
                        text: root.username
                        selectByMouse: true
                        enabled: !root.submitting && !root.checkingSession
                        onTextChanged: { root.username = text; root.message = "" }
                        onAccepted: passwordField.forceActiveFocus()
                    }

                    Text {
                        text: qsTr("PASSPHRASE")
                        color: "#809295"
                        font.family: "Courier New"
                        font.pixelSize: 8
                    }

                    TextField {
                        id: passwordField
                        width: parent.width
                        placeholderText: qsTr("Enter passphrase")
                        text: root.password
                        selectByMouse: true
                        enabled: !root.submitting && !root.checkingSession
                        echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                        onTextChanged: { root.password = text; root.message = "" }
                        onAccepted: root.authenticate()

                        ToolButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: parent.height
                            text: root.showPassword ? "◉" : "◎"
                            onClicked: root.showPassword = !root.showPassword
                        }
                    }

                    Text {
                        width: parent.width
                        visible: root.message !== ""
                        text: root.message
                        color: "#ef8c86"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    ModernActionButton {
                        id: submitButton
                        width: parent.width
                        implicitHeight: 40
                        text: root.submitting ? qsTr("AUTHENTICATING...") : (qsTr("AUTHENTICATE") + "  →")
                        enabled: !root.submitting && !root.checkingSession
                        primary: true
                        onClicked: root.authenticate()
                    }

                    ModernActionButton {
                        width: parent.width
                        implicitHeight: 36
                        text: qsTr("Skip FleetControl (Flash Standalone)  →")
                        onClicked: root.skipToStandaloneFlash()
                    }
                }
            }

            // SIGNED IN: FLEET MANAGEMENT VIEW
            Rectangle {
                visible: root.signedIn
                width: parent.width
                height: Math.max(0, root.height - y - 16)
                color: "#152130"
                border.width: 1
                border.color: "#263a4d"
                radius: 8

                Column {
                    anchors.fill: parent
                    anchors.margins: root.width < 700 ? 12 : 16
                    spacing: 10

                    // Responsive Header & Toolbar (Zero clipping, zero overlay)
                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        // Line 1: Breadcrumbs + Utility / Account actions
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Row {
                                spacing: 8
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: qsTr("FLEET COMMAND")
                                    color: "#00a6f2"
                                    font.family: "Courier New"
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.1
                                }
                                Text {
                                    text: "/  " + accountName.toUpperCase()
                                    color: "#7fa6b8"
                                    font.family: "Courier New"
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.1
                                    elide: Text.ElideRight
                                }
                            }

                            Item { Layout.fillWidth: true }

                            ModernActionButton {
                                visible: root.width >= 540
                                text: qsTr("Skip to Flashing  →")
                                implicitHeight: 28
                                onClicked: root.skipToStandaloneFlash()
                            }

                            ModernActionButton {
                                text: qsTr("Sign out")
                                implicitHeight: 28
                                onClicked: root.signOut()
                            }
                        }

                        // Line 2 (Desktop / Normal width >= 540): Title + Craft actions
                        RowLayout {
                            visible: root.width >= 540
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Aircraft & Ground Stations")
                                color: "#eff7f9"
                                font.pixelSize: root.width < 700 ? 17 : 19
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 8
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                ModernActionButton {
                                    text: qsTr("+ Add Unit")
                                    primary: true
                                    implicitHeight: 32
                                    onClicked: root.openNewUnitEditor()
                                }
                                ModernActionButton {
                                    text: qsTr("Refresh")
                                    implicitHeight: 32
                                    onClicked: root.loadCrafts()
                                }
                            }
                        }

                        // Line 2 (Narrow width < 540): Title on top, buttons in Flow
                        ColumnLayout {
                            visible: root.width < 540
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Aircraft & Ground Stations")
                                color: "#eff7f9"
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 8

                                ModernActionButton {
                                    text: qsTr("+ Add Unit")
                                    primary: true
                                    implicitHeight: 30
                                    onClicked: root.openNewUnitEditor()
                                }
                                ModernActionButton {
                                    text: qsTr("Refresh")
                                    implicitHeight: 30
                                    onClicked: root.loadCrafts()
                                }
                                ModernActionButton {
                                    text: qsTr("Skip to Flashing  →")
                                    implicitHeight: 30
                                    onClicked: root.skipToStandaloneFlash()
                                }
                            }
                        }
                    }

                    // Active craft indicator banner (if craft is selected)
                    Rectangle {
                        visible: root.activeCraftName.length > 0
                        width: parent.width
                        height: 38
                        radius: 6
                        color: "#102e42"
                        border.color: "#00a6f2"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Image {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                source: "../icons/ui/hub.svg"
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Active Unit for Flashing: <b>%1</b>").arg(root.activeCraftName)
                                color: "#e1f2fc"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            ModernActionButton {
                                text: qsTr("Clear Selection")
                                implicitHeight: 26
                                onClicked: root.clearActiveCraft()
                            }

                            ModernActionButton {
                                text: qsTr("Flash Now  →")
                                primary: true
                                implicitHeight: 26
                                onClicked: {
                                    if (mainWindow && mainWindow.writeWithFleetControlProfile)
                                        mainWindow.writeWithFleetControlProfile(root.activeCraftName)
                                }
                            }
                        }
                    }

                    // Status message
                    Text {
                        visible: root.message.length > 0
                        text: root.message
                        color: "#74d4ff"
                        font.pixelSize: 11
                    }

                    // Filter tabs (Flow ensures responsive wrapping on small widths)
                    Flow {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: [
                                { "text": qsTr("My Account Fleet (%1)").arg(craftModel.count), "val": 0 },
                                { "text": qsTr("Air Crafts"), "val": 1 },
                                { "text": qsTr("Ground Stations"), "val": 2 },
                                { "text": qsTr("Example Templates (%1)").arg(templateModel.count), "val": 3 }
                            ]

                            delegate: Rectangle {
                                width: filterText.implicitWidth + 20
                                height: 28
                                radius: 14
                                color: root.activeFilter === modelData.val ? "#00a6f2" : "#1a2c3d"
                                border.color: root.activeFilter === modelData.val ? "#4cc2f7" : "#2a435a"

                                Text {
                                    id: filterText
                                    anchors.centerIn: parent
                                    text: modelData.text
                                    color: root.activeFilter === modelData.val ? "#081b26" : "#b4c8d4"
                                    font.pixelSize: 11
                                    font.bold: root.activeFilter === modelData.val
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeFilter = modelData.val
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#1f3547"
                    }

                    // Crafts & Ground Stations List
                    ListView {
                        id: craftsListView
                        width: parent.width
                        height: Math.max(120, parent.height - y - 10)
                        clip: true
                        spacing: 8
                        model: root.activeFilter === 3 ? templateModel : craftModel

                        delegate: Item {
                            id: craftDelegateItem
                            width: craftsListView.width
                            readonly property bool isTemplate: root.activeFilter === 3
                            readonly property bool isMatchingFilter:
                                isTemplate ||
                                root.activeFilter === 0 ||
                                (root.activeFilter === 1 && craftCategory === "craft") ||
                                (root.activeFilter === 2 && craftCategory === "station")

                            height: isMatchingFilter ? 76 : 0
                            visible: isMatchingFilter

                            Rectangle {
                                anchors.fill: parent
                                color: craftHover.containsMouse ? "#1c2e42" : "#121d2b"
                                border.color: craftHover.containsMouse ? "#2f72a3" : "#22394d"
                                border.width: 1
                                radius: 6

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 12

                                    // Vehicle / Station Badge Icon
                                    Rectangle {
                                        Layout.preferredWidth: 46
                                        Layout.preferredHeight: 46
                                        radius: 10
                                        color: craftCategory === "craft" ? "#0f2f45" : "#1b3334"
                                        border.color: craftCategory === "craft" ? "#1e628e" : "#246663"
                                        border.width: 1

                                        Image {
                                            anchors.centerIn: parent
                                            width: 30
                                            height: 30
                                            source: root.iconSource(craftIcon)
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }
                                    }

                                    // Craft Details
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Row {
                                            spacing: 8

                                            Text {
                                                text: craftName
                                                color: "#f0f6fa"
                                                font.pixelSize: 15
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: roleBadgeText.implicitWidth + 8
                                                height: 16
                                                radius: 3
                                                color: craftCategory === "craft" ? "#14425a" : "#1c4a45"

                                                Text {
                                                    id: roleBadgeText
                                                    anchors.centerIn: parent
                                                    text: craftCategory === "craft" ? qsTr("AIR CRAFT") : qsTr("GROUND STATION")
                                                    color: craftCategory === "craft" ? "#5ec7f8" : "#4ee0d2"
                                                    font.family: "Courier New"
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }
                                            }

                                            Rectangle {
                                                visible: isTemplate
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: templateBadgeText.implicitWidth + 8
                                                height: 16
                                                radius: 3
                                                color: "#302611"

                                                Text {
                                                    id: templateBadgeText
                                                    anchors.centerIn: parent
                                                    text: qsTr("TEMPLATE")
                                                    color: "#f3c25b"
                                                    font.family: "Courier New"
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }
                                            }

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: hwBadgeText.implicitWidth + 8
                                                height: 16
                                                radius: 3
                                                color: "#182b3a"

                                                Text {
                                                    id: hwBadgeText
                                                    anchors.centerIn: parent
                                                    text: craftHardware
                                                    color: "#97b6c7"
                                                    font.pixelSize: 9
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: craftDescription.length > 0 ? craftDescription : qsTr("Configured for OpenHD digital link")
                                            color: "#7493a5"
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Action Buttons
                                    Row {
                                        spacing: 6
                                        Layout.alignment: Qt.AlignVCenter

                                        ModernActionButton {
                                            visible: isTemplate
                                            text: qsTr("Flash with Template")
                                            primary: true
                                            implicitHeight: 32
                                            onClicked: root.selectAndFlashCraft(templateModel.get(index))
                                        }

                                        ModernActionButton {
                                            visible: isTemplate
                                            text: qsTr("+ Save")
                                            implicitHeight: 32
                                            onClicked: root.importTemplate(templateModel.get(index))
                                        }

                                        ModernActionButton {
                                            visible: !isTemplate
                                            text: craftCategory === "craft" ? qsTr("Flash Craft") : qsTr("Flash Station")
                                            primary: true
                                            implicitHeight: 32
                                            onClicked: root.selectAndFlashCraft(craftModel.get(index))
                                        }

                                        ToolButton {
                                            visible: !isTemplate
                                            text: "⚙"
                                            font.pixelSize: 15
                                            ToolTip.visible: hovered
                                            ToolTip.text: qsTr("Configure write options")
                                            onClicked: root.openEditUnitEditor(index)
                                        }

                                        ToolButton {
                                            visible: !isTemplate
                                            text: "×"
                                            font.pixelSize: 16
                                            ToolTip.visible: hovered
                                            ToolTip.text: qsTr("Delete from fleet")
                                            onClicked: root.deleteCraft(index)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: craftHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }

                        // Responsive Empty State
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 24, 520)
                            height: emptyCol.implicitHeight + 36
                            visible: root.activeFilter !== 3 && craftModel.count === 0 && !root.loadingCrafts
                            color: "#0f1c29"
                            border.color: "#21364a"
                            radius: 8

                            Column {
                                id: emptyCol
                                anchors.centerIn: parent
                                spacing: 12
                                width: parent.width - 32

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("No units registered in your FleetControl account yet.")
                                    color: "#e3f0f7"
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("FleetControl helps you configure and sync settings across all your aircraft and ground stations. All FleetControl features are 100% optional.")
                                    color: "#7b98a8"
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Flow {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 8

                                    ModernActionButton {
                                        text: qsTr("+ Add Unit")
                                        primary: true
                                        implicitHeight: 32
                                        onClicked: root.openNewUnitEditor()
                                    }

                                    ModernActionButton {
                                        text: qsTr("Browse Templates (%1)").arg(templateModel.count)
                                        implicitHeight: 32
                                        onClicked: root.activeFilter = 3
                                    }

                                    ModernActionButton {
                                        text: qsTr("Skip & Flash Standalone  →")
                                        implicitHeight: 32
                                        onClicked: root.skipToStandaloneFlash()
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.loadingCrafts
                            text: qsTr("Syncing fleet with cloud gateway...")
                            color: "#718b96"
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }

    // ==============================================================
    // 2. FULL-TAB UNIT EDITOR (Fills the entire tab, 100% responsive)
    // ==============================================================
    Rectangle {
        id: unitEditor
        anchors.fill: parent
        visible: root.unitEditorVisible
        color: "#0d1b26"
        z: 10

        // Editor Header Bar
        Rectangle {
            id: editorHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.width < 600 ? 64 : 56
            color: "#111f2c"
            border.color: "#1c3244"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.width < 600 ? 12 : 20
                anchors.rightMargin: root.width < 600 ? 12 : 20
                spacing: 12

                // Back / Close
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: backHover.containsMouse ? "#1e3447" : "#152433"
                    border.color: "#243c52"

                    Text {
                        anchors.centerIn: parent
                        text: "←"
                        color: backHover.containsMouse ? "#ffffff" : "#7592a3"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    MouseArea {
                        id: backHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeEditor()
                    }
                }

                Image {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    source: "../icons/ui/hub.svg"
                    fillMode: Image.PreserveAspectFit
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: root.editIndex >= 0
                              ? qsTr("Edit Vehicle or Ground Station")
                              : qsTr("Add Vehicle or Ground Station to Fleet")
                        color: "#ffffff"
                        font.pixelSize: root.width < 600 ? 15 : 17
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Create a new unit and add it to your fleet.")
                        color: "#7592a3"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 34
                        radius: 6
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: headerCancelMouse.containsMouse ? "#ffffff" : "#8ea4b2"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            id: headerCancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeEditor()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: root.editIndex >= 0 ? 120 : 130
                        Layout.preferredHeight: 34
                        radius: 6
                        color: headerSaveMouse.containsMouse ? "#00b2ff" : "#009fe3"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: root.editIndex >= 0 ? "✓" : "+"
                                color: "#ffffff"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: root.editIndex >= 0 ? qsTr("Save Changes") : qsTr("Add to Fleet")
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: headerSaveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.collectAndSaveEditor()
                        }
                    }
                }
            }
        }

        // Scrollable Responsive Form
        Flickable {
            id: editorScroll
            anchors.top: editorHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentWidth: width
            contentHeight: editorContentCol.implicitHeight + 48
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: editorContentCol
                width: Math.min(parent.width - (parent.width < 600 ? 24 : 48), 740)
                x: Math.max(12, Math.round((parent.width - width) / 2))
                y: 20
                spacing: 16

                // Section 1: UNIT / VEHICLE NAME
                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        text: qsTr("UNIT / VEHICLE NAME")
                        color: "#7592a3"
                        font.family: "Courier New"
                        font.pixelSize: 10
                        font.letterSpacing: 1.2
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        height: 44
                        radius: 6
                        color: "#121e2a"
                        border.color: craftNameField.activeFocus ? "#00a6f2" : "#1e3345"
                        border.width: 1

                        Image {
                            id: tagIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            source: "../icons/ui/tag.svg"
                            fillMode: Image.PreserveAspectFit
                        }

                        TextField {
                            id: craftNameField
                            anchors.left: tagIcon.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            background: Rectangle { color: "transparent" }
                            color: "#ffffff"
                            placeholderText: qsTr("e.g. Recon Quad 7\", Tactical GCS Alpha, FPV Goggles")
                            placeholderTextColor: "#4b6475"
                            font.pixelSize: 13
                            selectByMouse: true
                        }
                    }
                }

                // Section 2: TYPE / ROLE
                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        text: qsTr("TYPE / ROLE")
                        color: "#7592a3"
                        font.family: "Courier New"
                        font.pixelSize: 10
                        font.letterSpacing: 1.2
                        font.bold: true
                    }

                    Row {
                        width: parent.width
                        spacing: 10

                        // Aircraft Option
                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 44
                            radius: 6
                            color: root.editorSelectedCategory === "craft" ? "#0d2d43" : "#121e2a"
                            border.color: root.editorSelectedCategory === "craft" ? "#00a6f2" : "#1e3345"
                            border.width: root.editorSelectedCategory === "craft" ? 2 : 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 10

                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 18
                                    source: "../icons/ui/hub.svg"
                                    fillMode: Image.PreserveAspectFit
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Aircraft / Vehicle")
                                    color: root.editorSelectedCategory === "craft" ? "#ffffff" : "#7592a3"
                                    font.pixelSize: 13
                                    font.bold: root.editorSelectedCategory === "craft"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.editorSelectedCategory = "craft"
                                    if (root.editorSelectedIcon.indexOf("station") === 0)
                                        root.editorSelectedIcon = "craft-quadcopter"
                                }
                            }
                        }

                        // Ground Station Option
                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 44
                            radius: 6
                            color: root.editorSelectedCategory === "station" ? "#0d2d43" : "#121e2a"
                            border.color: root.editorSelectedCategory === "station" ? "#00a6f2" : "#1e3345"
                            border.width: root.editorSelectedCategory === "station" ? 2 : 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 10

                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 18
                                    source: "../icons/ui/station-transmitter.svg"
                                    fillMode: Image.PreserveAspectFit
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Ground Station / Controller")
                                    color: root.editorSelectedCategory === "station" ? "#ffffff" : "#7592a3"
                                    font.pixelSize: 13
                                    font.bold: root.editorSelectedCategory === "station"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.editorSelectedCategory = "station"
                                    if (root.editorSelectedIcon.indexOf("craft") === 0)
                                        root.editorSelectedIcon = "station-military-gcs"
                                }
                            }
                        }
                    }
                }

                // Section 3: VEHICLE TYPE / STATION TYPE (Responsive cards)
                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        text: root.editorSelectedCategory === "craft" ? qsTr("VEHICLE TYPE") : qsTr("STATION TYPE")
                        color: "#7592a3"
                        font.family: "Courier New"
                        font.pixelSize: 10
                        font.letterSpacing: 1.2
                        font.bold: true
                    }

                    Flow {
                        id: vehicleTypeCardsFlow
                        width: parent.width
                        spacing: 8

                        readonly property var currentCards: root.editorSelectedCategory === "craft"
                            ? [
                                { "key": "craft-quadcopter", "label": qsTr("Quadcopter") },
                                { "key": "craft-plane", "label": qsTr("Fixed Wing") },
                                { "key": "craft-vtol", "label": qsTr("VTOL Hybrid") },
                                { "key": "craft-hexacopter", "label": qsTr("Hexacopter") },
                                { "key": "craft-rover", "label": qsTr("UGV Rover") }
                            ]
                            : [
                                { "key": "station-military-gcs", "label": qsTr("Tactical GCS") },
                                { "key": "station-goggles", "label": qsTr("FPV Goggles") },
                                { "key": "station-tracker", "label": qsTr("Antenna Tracker") },
                                { "key": "station-transmitter", "label": qsTr("RC Controller") }
                            ]

                        Repeater {
                            model: vehicleTypeCardsFlow.currentCards

                            delegate: Rectangle {
                                width: vehicleTypeCardsFlow.width >= 560
                                       ? Math.floor((vehicleTypeCardsFlow.width - (vehicleTypeCardsFlow.currentCards.length - 1) * 8) / vehicleTypeCardsFlow.currentCards.length)
                                       : Math.floor((vehicleTypeCardsFlow.width - 8) / 2)
                                height: 82
                                radius: 8
                                color: root.editorSelectedIcon === modelData.key ? "#0d2d43" : "#121e2a"
                                border.color: root.editorSelectedIcon === modelData.key ? "#00a6f2" : "#1e3345"
                                border.width: root.editorSelectedIcon === modelData.key ? 2 : 1

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 32
                                        height: 32
                                        source: root.iconSource(modelData.key)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: root.editorSelectedIcon === modelData.key ? "#ffffff" : "#7592a3"
                                        font.pixelSize: 11
                                        font.bold: root.editorSelectedIcon === modelData.key
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.editorSelectedIcon = modelData.key
                                }
                            }
                        }
                    }
                }

                // Section 4: HARDWARE PLATFORM
                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        text: qsTr("HARDWARE PLATFORM")
                        color: "#7592a3"
                        font.family: "Courier New"
                        font.pixelSize: 10
                        font.letterSpacing: 1.2
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        height: 44
                        radius: 6
                        color: "#121e2a"
                        border.color: "#1e3345"
                        border.width: 1

                        Image {
                            id: chipIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            source: "../icons/ui/chip.svg"
                            fillMode: Image.PreserveAspectFit
                        }

                        ComboBox {
                            id: hardwareDropdown
                            anchors.left: chipIcon.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            model: [
                                "Raspberry Pi (Pi 4 / Pi 5 / CM4 / Zero 2W)",
                                "Radxa Zero 3W / Rock 3 (RK3566)",
                                "Radxa Rock 5B / CM5 (RK3588)",
                                "OpenHD Core X20",
                                "OpenHD Core X21",
                                "PC / x86_64 Ground Station"
                            ]
                            background: Rectangle { color: "transparent" }
                            onCurrentTextChanged: {
                                root.editorSelectedHardware = currentText
                                root.refreshEditorVendors(false)
                            }
                        }
                    }
                }

                // Section 5: MISSION NOTES / DESCRIPTION
                Column {
                    width: parent.width
                    spacing: 6

                    RowLayout {
                        width: parent.width
                        Text {
                            text: qsTr("MISSION NOTES / DESCRIPTION")
                            color: "#7592a3"
                            font.family: "Courier New"
                            font.pixelSize: 10
                            font.letterSpacing: 1.2
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: qsTr("Optional")
                            color: "#526a7a"
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 70
                        radius: 6
                        color: "#121e2a"
                        border.color: craftDescField.activeFocus ? "#00a6f2" : "#1e3345"
                        border.width: 1

                        Image {
                            id: docIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            width: 18
                            height: 18
                            source: "../icons/ui/document.svg"
                            fillMode: Image.PreserveAspectFit
                        }

                        TextArea {
                            id: craftDescField
                            anchors.left: docIcon.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.top: parent.top
                            anchors.topMargin: 6
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            background: Rectangle { color: "transparent" }
                            color: "#ffffff"
                            placeholderText: qsTr("e.g. 5.8 GHz digital link, dual antenna, telemetry enabled")
                            placeholderTextColor: "#4b6475"
                            font.pixelSize: 12
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                        }
                    }
                }

                // Section 6: CONFIGURE OPENHD WRITE OPTIONS (Expandable full settings)
                Rectangle {
                    width: parent.width
                    height: advancedCol.implicitHeight + 20
                    radius: 8
                    color: "#0f1c29"
                    border.color: root.editorAdvancedOpen ? "#00a6f2" : "#1d3243"
                    border.width: 1

                    Column {
                        id: advancedCol
                        width: parent.width - 24
                        x: 12
                        y: 10
                        spacing: 12

                        // Toggle Header
                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Text {
                                text: "⚙"
                                color: "#00a6f2"
                                font.pixelSize: 14
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.editorSelectedCategory === "craft"
                                      ? qsTr("Configure Air Craft Write Options (Cameras, Connectors, Hotspot)")
                                      : qsTr("Configure Ground Station Write Options (Display Mode, Mapbox Satellite, Hotspot)")
                                color: "#dbe8f0"
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.editorAdvancedOpen ? "▲ Hide" : "▼ Expand"
                                color: "#00a6f2"
                                font.pixelSize: 11
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.editorAdvancedOpen = !root.editorAdvancedOpen
                            }
                        }

                        // Expanded controls
                        Column {
                            visible: root.editorAdvancedOpen
                            width: parent.width
                            spacing: 10

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#192e3f"
                            }

                            // ----------------------------------------------------
                            // AIR VEHICLE CONTROLS (Camera Vendor, Models, Res, CSI, IP)
                            // ----------------------------------------------------
                            Column {
                                width: parent.width
                                spacing: 10
                                visible: root.editorSelectedCategory === "craft"

                                // Camera Vendor Selection
                                Column {
                                    width: parent.width
                                    spacing: 4
                                    Text {
                                        text: qsTr("CAMERA VENDOR")
                                        color: "#7592a3"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                    ComboBox {
                                        id: vendorDropdown
                                        width: parent.width
                                        onCurrentIndexChanged: {
                                            if (currentIndex >= 0 && root.editorVendors.length > 0)
                                                root.refreshEditorCameras(false)
                                        }
                                    }
                                }

                                // Primary Camera & Resolution
                                Row {
                                    width: parent.width
                                    spacing: 10

                                    Column {
                                        width: (parent.width - 10) * 0.6
                                        spacing: 4
                                        Text {
                                            text: qsTr("PRIMARY CAMERA")
                                            color: "#7592a3"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                        ComboBox {
                                            id: cameraDropdown
                                            width: parent.width
                                            onCurrentIndexChanged: {
                                                if (currentIndex >= 0)
                                                    root.refreshEditorResolutions(false)
                                            }
                                        }
                                    }

                                    Column {
                                        width: (parent.width - 10) * 0.4
                                        spacing: 4
                                        visible: cameraDropdown.currentIndex > 0
                                        Text {
                                            text: qsTr("RESOLUTION")
                                            color: "#7592a3"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                        ComboBox {
                                            id: resDropdown
                                            width: parent.width
                                        }
                                    }
                                }

                                // Raspberry Pi 5 Primary CSI Connector
                                Column {
                                    width: parent.width
                                    spacing: 4
                                    visible: FleetProfilesHelper.sbcKeyFromHardware(root.editorSelectedHardware) === "rpi" &&
                                             FleetProfilesHelper.isRpiCsiCamera(root.settingsMap, cameraDropdown.currentText)
                                    Text {
                                        text: qsTr("PRIMARY CAMERA CONNECTOR (PI 5)")
                                        color: "#7592a3"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                    ComboBox {
                                        id: primaryPortDropdown
                                        width: 140
                                        model: ["CAM0", "CAM1"]
                                        onActivated: {
                                            if (secondaryPortDropdown.visible && secondaryPortDropdown.currentIndex === currentIndex)
                                                secondaryPortDropdown.currentIndex = currentIndex === 0 ? 1 : 0
                                        }
                                    }
                                }

                                // Primary IP Camera Setup
                                Column {
                                    width: parent.width
                                    spacing: 6
                                    visible: cameraDropdown.currentText === "IP-CAMERA"

                                    Text {
                                        text: qsTr("PRIMARY IP CAMERA SETUP")
                                        color: "#00a6f2"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 10

                                        Column {
                                            width: (parent.width - 10) * 0.35
                                            spacing: 4
                                            Text {
                                                text: qsTr("IP ADDRESS")
                                                color: "#7592a3"
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                            TextField {
                                                id: ipCamAddressField
                                                width: parent.width
                                                placeholderText: "192.168.144.108"
                                                selectByMouse: true
                                            }
                                        }

                                        Column {
                                            width: (parent.width - 10) * 0.65
                                            spacing: 4
                                            Text {
                                                text: qsTr("SOURCE PIPELINE")
                                                color: "#7592a3"
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                            TextField {
                                                id: ipCamPipelineField
                                                width: parent.width
                                                placeholderText: "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
                                                selectByMouse: true
                                            }
                                        }
                                    }
                                }

                                // Secondary Camera & Resolution
                                Row {
                                    width: parent.width
                                    spacing: 10

                                    Column {
                                        width: (parent.width - 10) * 0.6
                                        spacing: 4
                                        Text {
                                            text: qsTr("SECONDARY CAMERA (DUAL CAM)")
                                            color: "#7592a3"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                        ComboBox {
                                            id: camera2Dropdown
                                            width: parent.width
                                            onCurrentIndexChanged: {
                                                if (currentIndex >= 0)
                                                    root.refreshEditorSecondaryResolutions(false)
                                            }
                                        }
                                    }

                                    Column {
                                        width: (parent.width - 10) * 0.4
                                        spacing: 4
                                        visible: camera2Dropdown.currentIndex > 0
                                        Text {
                                            text: qsTr("SECONDARY RES")
                                            color: "#7592a3"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                        ComboBox {
                                            id: res2Dropdown
                                            width: parent.width
                                        }
                                    }
                                }

                                // Raspberry Pi 5 Secondary CSI Connector
                                Column {
                                    width: parent.width
                                    spacing: 4
                                    visible: FleetProfilesHelper.sbcKeyFromHardware(root.editorSelectedHardware) === "rpi" &&
                                             FleetProfilesHelper.isRpiCsiCamera(root.settingsMap, camera2Dropdown.currentText)
                                    Text {
                                        text: qsTr("SECONDARY CAMERA CONNECTOR (PI 5)")
                                        color: "#7592a3"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                    ComboBox {
                                        id: secondaryPortDropdown
                                        width: 140
                                        model: ["CAM0", "CAM1"]
                                        currentIndex: 1
                                        onActivated: {
                                            if (primaryPortDropdown.visible && primaryPortDropdown.currentIndex === currentIndex)
                                                primaryPortDropdown.currentIndex = currentIndex === 0 ? 1 : 0
                                        }
                                    }
                                }

                                // Secondary IP Camera Setup
                                Column {
                                    width: parent.width
                                    spacing: 6
                                    visible: camera2Dropdown.currentText === "IP-CAMERA"

                                    Text {
                                        text: qsTr("SECONDARY IP CAMERA SETUP")
                                        color: "#00a6f2"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 10

                                        Column {
                                            width: (parent.width - 10) * 0.35
                                            spacing: 4
                                            Text {
                                                text: qsTr("IP ADDRESS")
                                                color: "#7592a3"
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                            TextField {
                                                id: camera2IpAddressField
                                                width: parent.width
                                                placeholderText: "192.168.144.108"
                                                selectByMouse: true
                                            }
                                        }

                                        Column {
                                            width: (parent.width - 10) * 0.65
                                            spacing: 4
                                            Text {
                                                text: qsTr("SOURCE PIPELINE")
                                                color: "#7592a3"
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                            TextField {
                                                id: camera2IpPipelineField
                                                width: parent.width
                                                placeholderText: "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
                                                selectByMouse: true
                                            }
                                        }
                                    }
                                }
                            }

                            // ----------------------------------------------------
                            // GROUND STATION CONTROLS (Display Override & Mapbox API Key)
                            // ----------------------------------------------------
                            Column {
                                width: parent.width
                                spacing: 10
                                visible: root.editorSelectedCategory === "station"

                                // Display Output Resolution Override
                                Column {
                                    width: parent.width
                                    spacing: 6

                                    Text {
                                        text: qsTr("GROUND DISPLAY OUTPUT")
                                        color: "#7592a3"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 10

                                        CheckBox {
                                            id: displayForceSwitch
                                            text: qsTr("Force Display Mode")
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        TextField {
                                            id: displayWidthField
                                            width: 70
                                            text: "1920"
                                            placeholderText: "Width"
                                            enabled: displayForceSwitch.checked
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "×"
                                            color: "#7592a3"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        TextField {
                                            id: displayHeightField
                                            width: 70
                                            text: "1080"
                                            placeholderText: "Height"
                                            enabled: displayForceSwitch.checked
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "@"
                                            color: "#7592a3"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        TextField {
                                            id: displayFpsField
                                            width: 50
                                            text: "60"
                                            placeholderText: "Hz"
                                            enabled: displayForceSwitch.checked
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                // Mapbox API Key (Station Only)
                                Column {
                                    width: parent.width
                                    spacing: 4
                                    Text {
                                        text: qsTr("MAPBOX SATELLITE API KEY")
                                        color: "#7592a3"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                    Text {
                                        text: qsTr("Satellite imagery for telemetry and tracking display on ground stations.")
                                        color: "#526a7a"
                                        font.pixelSize: 11
                                    }
                                    TextField {
                                        id: mapboxKeyField
                                        width: parent.width
                                        placeholderText: qsTr("pk.eyJ1... (optional online satellite map)")
                                        selectByMouse: true
                                    }
                                }
                            }

                            // ----------------------------------------------------
                            // WiFi HotSpot Passphrase (Common)
                            // ----------------------------------------------------
                            Column {
                                width: parent.width
                                spacing: 4
                                Text {
                                    text: root.editorSelectedCategory === "craft" ? qsTr("AIR HOTSPOT PASSPHRASE") : qsTr("GROUND STATION HOTSPOT PASSPHRASE")
                                    color: "#7592a3"
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                                TextField {
                                    id: hotspotField
                                    width: parent.width
                                    placeholderText: root.editorSelectedCategory === "craft" ? qsTr("Default OpenHD AP if blank") : qsTr("openhd_gcs_secure (optional)")
                                    selectByMouse: true
                                }
                            }
                        }
                    }
                }

                // Bottom Footer: Cancel & Add/Save buttons
                RowLayout {
                    width: parent.width
                    spacing: 12

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 38
                        radius: 6
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: bottomCancelMouse.containsMouse ? "#ffffff" : "#8ea4b2"
                            font.pixelSize: 13
                            font.bold: true
                        }

                        MouseArea {
                            id: bottomCancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeEditor()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: root.editIndex >= 0 ? 130 : 140
                        Layout.preferredHeight: 38
                        radius: 6
                        color: bottomSaveMouse.containsMouse ? "#00b2ff" : "#009fe3"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: root.editIndex >= 0 ? "✓" : "+"
                                color: "#ffffff"
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                text: root.editIndex >= 0 ? qsTr("Save Changes") : qsTr("Add to Fleet")
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: bottomSaveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.collectAndSaveEditor()
                        }
                    }
                }
            }
        }
    }
}
