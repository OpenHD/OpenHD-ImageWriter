import QtQuick 2.9
import QtTest 1.2
import "../../qmlcomponents" as Components

Item {
    width: 900; height: 700
    property bool selection: false
    Components.OperationReviewPage {
        id: review
        anchors.fill: parent
        picoUsbOptions: true
        picoEthernetEnabled: selection
        onPicoEthernetToggled: function(enabled) { selection = enabled }
    }
    TestCase {
        name: "PicoUsbOptions"
        when: windowShown
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
