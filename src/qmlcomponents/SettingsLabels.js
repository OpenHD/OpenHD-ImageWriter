// Translate presentation labels while retaining the IDs used in settings files.
function translated(value) {
    switch (String(value)) {
    case "Air": return qsTranslate("SettingsLabels", "Air")
    case "Ground": return qsTranslate("SettingsLabels", "Ground")
    case "NONE": return qsTranslate("SettingsLabels", "None")
    case "Network": return qsTranslate("SettingsLabels", "Network")
    case "Advanced": return qsTranslate("SettingsLabels", "Advanced")
    case "Generic": return qsTranslate("SettingsLabels", "Generic")
    case "Integrated camera": return qsTranslate("SettingsLabels", "Integrated camera")
    case "IP CAMERA":
    case "IP-CAMERA": return qsTranslate("SettingsLabels", "IP camera")
    case "DEV CAMERA":
    case "TESTPATTERN": return qsTranslate("SettingsLabels", "Test camera")
    case "EXTERNAL": return qsTranslate("SettingsLabels", "External camera")
    case "FILESRC": return qsTranslate("SettingsLabels", "File source")
    case "2MPCAMERAS": return qsTranslate("SettingsLabels", "2 MP cameras")
    default: return value
    }
}
