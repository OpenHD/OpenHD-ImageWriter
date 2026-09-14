.pragma library

/*
 * The remote catalog is data, not UI configuration.  New catalogs may be a
 * bare array or expose an `images` array.  `os_list` and nested `subitems`
 * remain supported so an old release asset can be used as a fallback.
 */

function _copy(source) {
    var target = {}
    for (var key in source)
        target[key] = source[key]
    return target
}

function _isArray(value) {
    return Array.isArray(value)
}

function _text(entry) {
    return (String(entry.platform || "") + " " +
            String(entry.manufacturer || entry.vendor || entry.brand || "") + " " +
            String(entry.device || "") + " " +
            String(entry.target || "") + " " +
            String(entry.board || "") + " " +
            String(entry._catalog_context || "") + " " +
            String(entry.name || "") + " " +
            String(entry.description || "") + " " +
            String(entry.url || "")).toLowerCase()
}

function _contains(value, words) {
    for (var i = 0; i < words.length; ++i) {
        if (value.indexOf(words[i]) >= 0)
            return true
    }
    return false
}

function _hardware(entry) {
    var value = _text(entry)

    /* OpenHD's own boards are intentionally the first manufacturer. */
    if (_contains(value, ["x20", "x-20"]))
        return { manufacturer: "openhd", manufacturerName: "OpenHD Hardware", manufacturerOrder: 10,
                 board: "x20", boardName: "X20", boardOrder: 10, icon: "icons/manufacturers/openhd-mono.svg" }
    if (_contains(value, ["x21", "x-21"]))
        return { manufacturer: "openhd", manufacturerName: "OpenHD Hardware", manufacturerOrder: 10,
                 board: "x21", boardName: "X21", boardOrder: 20, icon: "icons/manufacturers/openhd-mono.svg" }
    if (_contains(value, ["raspberry", "rpi", "image-pi-"])) {
        if (_contains(value, ["cm0", "compute-module-0", "compute module 0"]))
            return { manufacturer: "raspberry-pi", manufacturerName: "Raspberry Pi", manufacturerOrder: 20,
                     board: "raspberry-cm0", boardName: "Raspberry CM0", boardOrder: 30, icon: "icons/manufacturers/raspberrypi-mono.svg" }
        if (_contains(value, ["cm3", "cm4", "compute module 3", "compute module 4"]))
            return { manufacturer: "raspberry-pi", manufacturerName: "Raspberry Pi", manufacturerOrder: 20,
                     board: "raspberry-cm3-4", boardName: "Compute Module 3 / 4", boardOrder: 20, icon: "icons/manufacturers/raspberrypi-mono.svg" }
        if (_contains(value, ["rpi5", "pi-5", "pi 5", "raspberrypi5"]))
            return { manufacturer: "raspberry-pi", manufacturerName: "Raspberry Pi", manufacturerOrder: 20,
                     board: "raspberry-pi-5", boardName: "Raspberry Pi 5", boardOrder: 40, icon: "icons/manufacturers/raspberrypi-mono.svg" }
        return { manufacturer: "raspberry-pi", manufacturerName: "Raspberry Pi", manufacturerOrder: 20,
                 board: "raspberry-pi-2-4", boardName: "Raspberry Pi 2–4", boardOrder: 10, icon: "icons/manufacturers/raspberrypi-mono.svg" }
    }

    if (_contains(value, ["radxa", "rock5", "rock 5", "rock3", "rock 3", "rockcm", "cubiea7", "cubie a7"])) {
        var radxaBoard = { key: "radxa-other", name: "Other Radxa", order: 90 }
        if (_contains(value, ["rock5a", "rock 5a", "rock-5a"])) radxaBoard = { key: "rock5a", name: "ROCK 5A", order: 10 }
        else if (_contains(value, ["rock5b", "rock 5b", "rock-5b"])) radxaBoard = { key: "rock5b", name: "ROCK 5B", order: 20 }
        else if (_contains(value, ["rock3a", "rock 3a", "rock-3a"])) radxaBoard = { key: "rock3a", name: "ROCK 3A", order: 30 }
        else if (_contains(value, ["rockcm3", "rock cm3", "rock-cm3"])) radxaBoard = { key: "rock-cm3", name: "ROCK CM3", order: 40 }
        else if (_contains(value, ["cubiea7", "cubie a7", "cubie-a7"])) radxaBoard = { key: "cubie-a7", name: "Cubie A7", order: 50 }
        return { manufacturer: "radxa", manufacturerName: "Radxa", manufacturerOrder: 30,
                 board: radxaBoard.key, boardName: radxaBoard.name, boardOrder: radxaBoard.order,
                 icon: "icons/manufacturers/radxa-mono.svg" }
    }

    if (_contains(value, ["luckfox", "luck fox", "aura", "lyra"]) ||
            (_contains(value, ["pico"]) && !_contains(value, ["raspberry"]))) {
        var luckfoxBoard = { key: "luckfox-other", name: "Other Luckfox", order: 90 }
        if (_contains(value, ["aura"])) luckfoxBoard = { key: "aura", name: "Aura", order: 10 }
        else if (_contains(value, ["pico"])) luckfoxBoard = { key: "pico", name: "Pico", order: 20 }
        else if (_contains(value, ["lyra"])) luckfoxBoard = { key: "lyra", name: "Lyra", order: 30 }
        return { manufacturer: "luckfox", manufacturerName: "Luckfox", manufacturerOrder: 40,
                 board: luckfoxBoard.key, boardName: luckfoxBoard.name, boardOrder: luckfoxBoard.order,
                 icon: "icons/manufacturers/luckfox-mono.svg" }
    }

    if (_contains(value, ["orange pi", "orangepi", "zero3w", "zero 3w"])) {
        var orangeBoard = _contains(value, ["cm4", "compute module 4"])
                ? { key: "orange-pi-cm4", name: "CM4", order: 20 }
                : { key: "orange-pi-zero-3w", name: "Zero 3W", order: 10 }
        return { manufacturer: "orange-pi", manufacturerName: "Orange Pi", manufacturerOrder: 50,
                 board: orangeBoard.key, boardName: orangeBoard.name, boardOrder: orangeBoard.order,
                 icon: "icons/manufacturers/orangepi-mono.svg" }
    }

    if (_contains(value, ["orqa", "gcb"]))
        return { manufacturer: "orqa", manufacturerName: "Orqa", manufacturerOrder: 60,
                 board: "gcb", boardName: "GCB", boardOrder: 10, icon: "icons/manufacturers/orqa-mono.svg" }

    if (_contains(value, ["uxv", "module-35", "module 35", "module35"]))
        return { manufacturer: "uxv", manufacturerName: "UXV", manufacturerOrder: 70,
                 board: "module-35", boardName: "Module-35", boardOrder: 10, icon: "icons/manufacturers/uxv-mono.svg" }

    if (_contains(value, ["x86", "amd64", "desktop", "intel", "computer"]))
        return { manufacturer: "x86", manufacturerName: "x86 / PC", manufacturerOrder: 80,
                 board: "x86", boardName: "Intel / AMD systems", boardOrder: 10, icon: "icons/manufacturers/x86-mono.svg" }
    if (_contains(value, ["jetson"]))
        return { manufacturer: "other", manufacturerName: "Other Hardware", manufacturerOrder: 900,
                 board: "jetson", boardName: "NVIDIA Jetson", boardOrder: 20, icon: "icons/manufacturers/more-mono.svg" }

    return { manufacturer: "other", manufacturerName: "Other Hardware", manufacturerOrder: 900,
             board: "other", boardName: "Other boards", boardOrder: 90, icon: "icons/manufacturers/more-mono.svg" }
}

function _channel(entry) {
    var explicit = String(entry.channel || entry.stream || entry.release_channel || "").toLowerCase()
    if (explicit === "dev" || explicit === "development" || explicit === "nightly" ||
            explicit === "snapshot" || explicit === "testing" || explicit === "beta")
        return "development"
    if (explicit === "stable" || explicit === "release" || explicit === "official")
        return "stable"

    var value = _text(entry)
    return value.indexOf("development") >= 0 || value.indexOf("nightly") >= 0 ||
            value.indexOf("snapshot") >= 0 || value.indexOf("testing") >= 0 ||
            value.indexOf("beta") >= 0 || value.indexOf("dev-release") >= 0
            ? "development" : "stable"
}

function _manufacturerDescription(manufacturer) {
    if (manufacturer === "openhd") return "X20 and X21"
    if (manufacturer === "raspberry-pi") return "Pi 2–5 and Compute Modules"
    if (manufacturer === "radxa") return "ROCK 3, ROCK 5, CM3 and Cubie A7"
    if (manufacturer === "luckfox") return "Aura, Pico and Lyra"
    if (manufacturer === "orange-pi") return "Zero 3W and CM4"
    if (manufacturer === "orqa") return "GCB hardware"
    if (manufacturer === "uxv") return "Module-35 hardware"
    if (manufacturer === "x86") return "Intel and AMD systems"
    return "x86 PCs and other supported boards"
}

function _dateKey(entry) {
    var value = String(entry.release_date || entry.created_at || entry.uploaded_at || entry.date || "")
    var match = value.match(/(\d{4})[-_](\d{2})[-_](\d{2})(?:[T_ -]?(\d{2})[:_-]?(\d{2})[:_-]?(\d{2})?)?/)
    if (match)
        return match[1] + match[2] + match[3] + (match[4] || "00") +
                (match[5] || "00") + (match[6] || "00")

    /* Some legacy manifests used YYYY-DD-MM. It still sorts consistently. */
    return value.replace(/[^0-9]/g, "")
}

function _versionParts(entry) {
    var match = String(entry.version || entry.name || "").match(/(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?/)
    if (!match)
        return [0, 0, 0, 0]
    return [Number(match[1] || 0), Number(match[2] || 0),
            Number(match[3] || 0), Number(match[4] || 0)]
}

function _newestFirst(a, b) {
    var dateOrder = _dateKey(b).localeCompare(_dateKey(a))
    if (dateOrder !== 0)
        return dateOrder

    var av = _versionParts(a)
    var bv = _versionParts(b)
    for (var i = 0; i < av.length; ++i) {
        if (av[i] !== bv[i])
            return bv[i] - av[i]
    }
    return String(a.name || "").localeCompare(String(b.name || ""))
}

function _containsExternalList(list) {
    for (var i = 0; i < list.length; ++i) {
        if (list[i].subitems_url)
            return true
        if (_isArray(list[i].subitems) && _containsExternalList(list[i].subitems))
            return true
    }
    return false
}

function _legacyFallback(list) {
    var result = []
    for (var i = 0; i < list.length; ++i) {
        var entry = _copy(list[i])
        if (_isArray(entry.subitems)) {
            entry.subitems = _legacyFallback(entry.subitems)
            entry.subitems.sort(_newestFirst)
        }
        result.push(entry)
    }
    return result
}

function _collectImages(list, context, result) {
    for (var i = 0; i < list.length; ++i) {
        var entry = _copy(list[i])
        var nextContext = (context + " " + String(entry.name || "") + " " +
                           String(entry.description || "")).trim()
        if (_isArray(entry.subitems)) {
            _collectImages(entry.subitems, nextContext, result)
        } else if (entry.url) {
            entry._catalog_context = context
            result.push(entry)
        }
    }
}

function _normaliseFlat(list) {
    var manufacturers = {}
    var seen = {}

    for (var i = 0; i < list.length; ++i) {
        var image = _copy(list[i])
        if (!image.url)
            continue

        var hardware = _hardware(image)
        var channel = _channel(image)
        var duplicateKey = String(image.url).toLowerCase()
        if (seen[duplicateKey])
            continue
        seen[duplicateKey] = true

        image.manufacturer = hardware.manufacturer
        image.platform = hardware.board
        image.channel = channel
        image.icon = hardware.icon
        delete image._catalog_context

        var manufacturerKey = channel + ":" + hardware.manufacturer
        if (!manufacturers[manufacturerKey]) {
            manufacturers[manufacturerKey] = {
                name: hardware.manufacturerName,
                description: channel === "development"
                             ? "Development images for " + hardware.manufacturerName
                             : _manufacturerDescription(hardware.manufacturer),
                icon: hardware.icon,
                url: "",
                channel: channel,
                manufacturer: hardware.manufacturer,
                manufacturer_order: hardware.manufacturerOrder,
                board_groups: {}
            }
        }
        var manufacturer = manufacturers[manufacturerKey]
        if (!manufacturer.board_groups[hardware.board]) {
            manufacturer.board_groups[hardware.board] = {
                name: hardware.boardName,
                description: "OpenHD images for " + hardware.boardName,
                icon: hardware.icon,
                url: "",
                channel: channel,
                manufacturer: hardware.manufacturer,
                platform: hardware.board,
                board_order: hardware.boardOrder,
                subitems: []
            }
        }
        manufacturer.board_groups[hardware.board].subitems.push(image)
    }

    var result = []
    for (var key in manufacturers) {
        var group = manufacturers[key]
        group.subitems = []
        for (var boardKey in group.board_groups) {
            group.board_groups[boardKey].subitems.sort(_newestFirst)
            group.subitems.push(group.board_groups[boardKey])
        }
        group.subitems.sort(function(a, b) {
            var order = a.board_order - b.board_order
            return order !== 0 ? order : a.name.localeCompare(b.name)
        })
        delete group.board_groups
        result.push(group)
    }
    result.sort(function(a, b) {
        if (a.channel !== b.channel)
            return a.channel === "stable" ? -1 : 1
        var order = a.manufacturer_order - b.manufacturer_order
        return order !== 0 ? order : a.name.localeCompare(b.name)
    })
    return result
}

function _selectedList(document, localeName) {
    if (_isArray(document))
        return document
    if (!document || typeof document !== "object")
        return null
    if (_isArray(document.images))
        return document.images

    var locale = String(localeName || "")
    if (locale && _isArray(document["os_list_" + locale]))
        return document["os_list_" + locale]
    var separator = locale.indexOf("_")
    if (separator > 0 && _isArray(document["os_list_" + locale.substring(0, separator)]))
        return document["os_list_" + locale.substring(0, separator)]
    return _isArray(document.os_list) ? document.os_list : null
}

function normalise(document, localeName) {
    var list = _selectedList(document, localeName)
    if (!_isArray(list))
        return null

    if (_containsExternalList(list))
        return _legacyFallback(list)

    var images = []
    _collectImages(list, "", images)
    return _normaliseFlat(images)
}

function flattenSubitems(list) {
    var result = []
    for (var i = 0; i < list.length; ++i) {
        var entry = _copy(list[i])
        if (_isArray(entry.subitems)) {
            entry.subitems_json = JSON.stringify(entry.subitems)
            delete entry.subitems
        }
        delete entry.manufacturer_order
        delete entry.board_order
        result.push(entry)
    }
    return result
}
