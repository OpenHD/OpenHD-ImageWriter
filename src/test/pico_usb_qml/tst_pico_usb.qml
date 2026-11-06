import QtQuick 2.9
import QtTest 1.2
import "../../qmlcomponents" as Components

Item {
    width: 900; height: 700
    property bool selection: false
    property bool configureOpened: false
    Components.OperationReviewPage {
        id: review
        anchors.fill: parent
        picoUsbOptions: true
        configurationAvailable: true
        onConfigureRequested: configureOpened = true
        picoEthernetEnabled: selection
        onPicoEthernetToggled: function(enabled) { selection = enabled }
    }
    TestCase {
        name: "PicoUsbOptions"
        when: windowShown
        function test_optional_pico_settings() {
            review.picoUsbOptions = true
            configureOpened = false
            var headerButton = findChild(review, "reviewSettingsButton")
            verify(headerButton !== null)
            verify(headerButton.visible)
            mouseClick(headerButton)
            compare(configureOpened, true)
            configureOpened = false
            var button = findChild(review, "configureImageButton")
            verify(button !== null)
            compare(review.configurationRequired, false)
            verify(button.visible)
            mouseClick(button)
            compare(configureOpened, true)
        }
        function test_toggle_and_other_boards() {
            var checkbox = findChild(review, "picoEthernetLinkCheck")
            verify(checkbox !== null)
            verify(checkbox.visible)
            compare(checkbox.checked, false)
            mouseClick(checkbox)
            compare(selection, true)
            compare(checkbox.checked, true)
            mouseClick(checkbox)
            compare(selection, false)
            review.picoUsbOptions = false
            verify(!checkbox.visible)
        }
    }
}
