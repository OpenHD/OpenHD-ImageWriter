.pragma library

var _cachedSettingsMap = null;

function getSettingsMap(imageWriter) {
    if (_cachedSettingsMap) return _cachedSettingsMap;
    if (!imageWriter) return null;
    try {
        var raw = imageWriter.readResourceText(":/doc/openhd_settings_map.json");
        if (raw && raw.length > 0) {
            _cachedSettingsMap = JSON.parse(raw);
        }
    } catch (e) {
        console.log("Failed to load settingsMap in FleetProfilesHelper: " + e);
    }
    return _cachedSettingsMap;
}

function iconSource(key) {
    var map = {
        "survey": "../icons/fleetcontrol/craft-survey-cutout.png",
        "heavy-lift": "../icons/fleetcontrol/craft-heavy-lift-cutout.png",
        "racer": "../icons/fleetcontrol/craft-racer-cutout.png",
        "whoop": "../icons/fleetcontrol/craft-whoop-cutout.png",
        "plane": "../icons/fleetcontrol/craft-plane-cutout.png",
        "rover": "../icons/fleetcontrol/craft-rover-cutout.png",
        "boat": "../icons/fleetcontrol/craft-boat-cutout.png",
        "submarine": "../icons/fleetcontrol/craft-submarine-cutout.png",
        "craft-quadcopter": "../icons/fleetcontrol/craft-survey-cutout.png",
        "craft-plane": "../icons/fleetcontrol/craft-plane-cutout.png",
        "craft-vtol": "../icons/fleetcontrol/craft-plane-cutout.png",
        "craft-hexacopter": "../icons/fleetcontrol/craft-heavy-lift-cutout.png",
        "craft-rover": "../icons/fleetcontrol/craft-rover-cutout.png",
        "station-goggles": "../icons/ui/station-goggles.svg",
        "station-tracker": "../icons/ui/station-tracker.svg",
        "station-transmitter": "../icons/ui/station-transmitter.svg",
        "station-military-gcs": "../icons/ui/station-military-gcs.svg",
        "hub": "../icons/ui/hub.svg"
    };
    return map[key] || "../icons/ui/hub.svg";
}

function sbcKeyFromHardware(hw) {
    hw = (hw || "").toLowerCase();
    if (hw.indexOf("x21") >= 0) return "x21";
    if (hw.indexOf("x20") >= 0) return "x20";
    if (hw.indexOf("rock 5") >= 0 || hw.indexOf("rock-5") >= 0 || hw.indexOf("cm5") >= 0 || hw.indexOf("rk3588") >= 0) return "rock-5b";
    if (hw.indexOf("zero 3") >= 0 || hw.indexOf("zero3") >= 0 || hw.indexOf("rock 3") >= 0 || hw.indexOf("cm3") >= 0 || hw.indexOf("rk3566") >= 0) return "zero3w";
    if (hw.indexOf("x86") >= 0 || hw.indexOf("pc") >= 0 || hw.indexOf("laptop") >= 0) return "x86";
    if (hw.indexOf("qualcomm") >= 0 || hw.indexOf("qcs") >= 0 || hw.indexOf("qrb") >= 0) return "qcs405";
    if (hw.indexOf("openipc") >= 0) return "openipc";
    if (hw.indexOf("raspberry") >= 0 || hw.indexOf("rpi") >= 0) return "rpi";
    return "rpi";
}

function getVendorsForSbc(settingsMap, sbcKey) {
    if (!settingsMap || !settingsMap.camera || !settingsMap.camera.sbcGroups) return [];
    var list = [];
    var common = settingsMap.camera.commonVendors || [];
    for (var i = 0; i < settingsMap.camera.sbcGroups.length; i++) {
        var group = settingsMap.camera.sbcGroups[i];
        if (group && group.sbc && group.sbc.indexOf(sbcKey) !== -1) {
            var groupVendors = group.vendors || [];
            for (var v = 0; v < groupVendors.length; v++) {
                list.push(groupVendors[v]);
            }
            break;
        }
    }
    for (var c = 0; c < common.length; c++) {
        list.push(common[c]);
    }
    return list;
}

function getResolutionsForCamera(settingsMap, sbcKey, vendorId, cameraId) {
    if (!settingsMap || !settingsMap.cameraResolution || !settingsMap.cameraResolution.byCameraValue || !cameraId) {
        return [];
    }
    if (cameraId === "NONE" || cameraId.length === 0) return [];

    var valueWritten = "";
    var vendors = getVendorsForSbc(settingsMap, sbcKey);
    for (var v = 0; v < vendors.length; v++) {
        if (!vendorId || vendors[v].id === vendorId || vendors[v].displayName === vendorId) {
            var opts = vendors[v].options || [];
            for (var o = 0; o < opts.length; o++) {
                if (opts[o].id === cameraId) {
                    valueWritten = opts[o].valueWritten || "";
                    break;
                }
            }
            if (valueWritten.length > 0) break;
        }
    }

    if (valueWritten.length === 0) {
        // Search all vendors for sbcKey as fallback
        for (var v2 = 0; v2 < vendors.length; v2++) {
            var opts2 = vendors[v2].options || [];
            for (var o2 = 0; o2 < opts2.length; o2++) {
                if (opts2[o2].id === cameraId) {
                    valueWritten = opts2[o2].valueWritten || "";
                    break;
                }
            }
            if (valueWritten.length > 0) break;
        }
    }

    if (valueWritten === "1") valueWritten = "10";
    if (valueWritten.length === 0) return [];

    return settingsMap.cameraResolution.byCameraValue[valueWritten] || [];
}

function getSecondaryCameraOptions(settingsMap, sbcKey) {
    var list = [{ id: "", displayName: "NONE" }];
    if (!settingsMap || !settingsMap.camera) return list;

    var secOpts = settingsMap.camera.secondaryOptions || [];
    for (var i = 0; i < secOpts.length; i++) {
        list.push({ id: secOpts[i].id, displayName: secOpts[i].displayName || secOpts[i].id, valueWritten: secOpts[i].valueWritten });
    }

    // If SBC supports secondary CSI (e.g. Raspberry Pi), include CSI cameras
    for (var g = 0; g < (settingsMap.camera.sbcGroups || []).length; g++) {
        var group = settingsMap.camera.sbcGroups[g];
        if (group && group.sbc && group.sbc.indexOf(sbcKey) !== -1 && group.secondaryCsi && group.vendors) {
            for (var vi = 0; vi < group.vendors.length; vi++) {
                var vOpts = group.vendors[vi].options || [];
                for (var oi = 0; oi < vOpts.length; oi++) {
                    var csiOpt = vOpts[oi];
                    var cType = parseInt(csiOpt.valueWritten);
                    if (cType >= 20 && cType <= 69) {
                        list.push({ id: csiOpt.id, displayName: "CSI - " + csiOpt.id, valueWritten: csiOpt.valueWritten });
                    }
                }
            }
            break;
        }
    }

    return list;
}

function getResolutionsForSecondaryCamera(settingsMap, sbcKey, cameraId) {
    if (!settingsMap || !settingsMap.cameraResolution || !settingsMap.cameraResolution.byCameraValue || !cameraId) {
        return [];
    }
    if (cameraId === "NONE" || cameraId.length === 0) return [];

    var secList = getSecondaryCameraOptions(settingsMap, sbcKey);
    var valueWritten = "";
    for (var i = 0; i < secList.length; i++) {
        if (secList[i].id === cameraId) {
            valueWritten = secList[i].valueWritten || "";
            break;
        }
    }

    if (valueWritten === "1") valueWritten = "10";
    if (valueWritten.length === 0) return [];

    return settingsMap.cameraResolution.byCameraValue[valueWritten] || [];
}

function isRpiCsiCamera(settingsMap, cameraId) {
    if (!cameraId || !settingsMap || !settingsMap.camera || !settingsMap.camera.sbcGroups) return false;
    for (var g = 0; g < settingsMap.camera.sbcGroups.length; g++) {
        var grp = settingsMap.camera.sbcGroups[g];
        if (grp.sbc && grp.sbc.indexOf("rpi") !== -1 && grp.vendors) {
            for (var v = 0; v < grp.vendors.length; v++) {
                var opts = grp.vendors[v].options || [];
                for (var o = 0; o < opts.length; o++) {
                    if (opts[o].id === cameraId) {
                        var val = parseInt(opts[o].valueWritten);
                        return val >= 20 && val <= 69;
                    }
                }
            }
        }
    }
    return false;
}

function normalizeCamera(cam) {
    cam = cam || "";
    if (cam === "None (Single Camera)" || cam === "NONE") return "";
    return cam;
}

function normalizeResolution(res) {
    res = res || "";
    return res;
}

function loadProfiles(imageWriter) {
    var list = [];
    if (!imageWriter)
        return list;

    var accountName = imageWriter.getValue("fleetcontrol_username") || imageWriter.getValue("fleetcontrol_user") || "";
    var cacheKey = imageWriter.getValue("fleetcontrol_profile_cache_key") ||
                   ("fleetcontrol_crafts_" + (accountName && accountName.length > 0 ? accountName.toLowerCase() : "default"));
    var localData = imageWriter.getValue(cacheKey);

    if (localData && localData.length > 5) {
        try {
            var parsed = JSON.parse(localData);
            if (Array.isArray(parsed)) {
                for (var i = 0; i < parsed.length; ++i) {
                    var p = parsed[i];
                    if (p && p.name) {
                        list.push({
                            craftId: p.id || ("craft_" + i),
                            craftName: p.name,
                            craftCategory: p.category || "craft",
                            craftIcon: p.icon || (p.category === "station" ? "station-military-gcs" : "survey"),
                            craftRole: p.role || (p.category === "station" ? "ground" : "air"),
                            craftHardware: p.hardware || "Raspberry Pi",
                            craftDescription: p.description || "",
                            craftCameraVendor: p.cameraVendor || "",
                            craftCamera: p.camera || "",
                            craftCameraResolution: p.cameraResolution || "",
                            craftCameraPort: p.cameraPort || "cam1",
                            craftCamera2Vendor: p.camera2Vendor || "",
                            craftCamera2: p.camera2 || "",
                            craftCamera2Resolution: p.camera2Resolution || "",
                            craftCamera2Port: p.camera2Port || "cam0",
                            craftIpCameraAddress: p.ipCameraAddress || "",
                            craftIpCameraPipeline: p.ipCameraPipeline || "",
                            craftCamera2IpAddress: p.camera2IpCameraAddress || p.camera2IpAddress || "",
                            craftCamera2IpPipeline: p.camera2IpCameraPipeline || p.camera2IpPipeline || "",
                            craftIpCameraBitrate: p.ipCameraBitrate || 2,
                            craftHotSpot: p.hotSpot || "",
                            craftDisplayForceMode: p.displayForceMode || false,
                            craftDisplayWidth: p.displayWidth || 1920,
                            craftDisplayHeight: p.displayHeight || 1080,
                            craftDisplayRefreshHz: p.displayRefreshHz || 60,
                            craftMapboxApiKey: p.mapboxApiKey || ""
                        });
                    }
                }
            }
        } catch (e) {}
    }

    return list;
}

function applyProfile(imageWriter, p) {
    if (!imageWriter || !p) return;
    var role = p.craftRole || (p.craftCategory === "station" ? "ground" : "air");
    var sbcKey = sbcKeyFromHardware(p.craftHardware);

    imageWriter.setSetting("mode", role);
    imageWriter.setSetting("bootType", role === "ground" ? "Ground" : "Air");
    imageWriter.setSetting("sbc", sbcKey);
    imageWriter.setSetting("useSettings", true);
    imageWriter.setSetting("fleetcontrol_craft_id", p.craftId || "");
    imageWriter.setSetting("fleetcontrol_craft_name", p.craftName || "");

    var cam = normalizeCamera(p.craftCamera);
    var res = normalizeResolution(p.craftCameraResolution);
    var cam2 = normalizeCamera(p.craftCamera2);
    var res2 = normalizeResolution(p.craftCamera2Resolution);

    imageWriter.setSetting("camera", cam);
    imageWriter.setSetting("cameraResolution", res);
    imageWriter.setSetting("camera2", cam2);
    imageWriter.setSetting("camera2Resolution", res2);
    imageWriter.setSetting("cameraPort", p.craftCameraPort || "cam1");
    imageWriter.setSetting("camera2Port", p.craftCamera2Port || "cam0");
    imageWriter.setSetting("ipCameraAddress", p.craftIpCameraAddress || "");
    imageWriter.setSetting("ipCameraPipeline", p.craftIpCameraPipeline || "");
    imageWriter.setSetting("camera2IpCameraAddress", p.craftCamera2IpAddress || "");
    imageWriter.setSetting("camera2IpCameraPipeline", p.craftCamera2IpPipeline || "");
    imageWriter.setSetting("ipCameraBitrate", p.craftIpCameraBitrate || 2);

    imageWriter.setSetting("hotSpot", p.craftHotSpot || "");

    if (role === "ground") {
        imageWriter.setSetting("displayForceMode", p.craftDisplayForceMode !== undefined ? p.craftDisplayForceMode : false);
        imageWriter.setSetting("displayWidth", p.craftDisplayWidth || 1920);
        imageWriter.setSetting("displayHeight", p.craftDisplayHeight || 1080);
        imageWriter.setSetting("displayRefreshHz", p.craftDisplayRefreshHz || 60);
        imageWriter.setSetting("mapboxApiKey", p.craftMapboxApiKey || "");
    } else {
        imageWriter.setSetting("displayForceMode", false);
        imageWriter.setSetting("mapboxApiKey", "");
    }
}

function profileSummary(p) {
    if (!p) return "";
    var parts = [];
    var role = (p.craftRole || (p.craftCategory === "station" ? "ground" : "air")).toUpperCase();
    parts.push(role);
    if (p.craftHardware && p.craftHardware.length > 0)
        parts.push(p.craftHardware);
    var cam = p.craftCamera || "";
    if (cam.length > 0 && cam !== "None (Single Camera)" && cam !== "NONE") {
        var res = p.craftCameraResolution || "";
        parts.push(cam + (res.length > 0 ? " (" + res + ")" : ""));
    }
    if (p.craftHotSpot && p.craftHotSpot.length > 0)
        parts.push("Hotspot: " + p.craftHotSpot);
    return parts.join(" \u2022 ");
}
