import QtQuick 2.9
import QtQuick.Controls 2.2
import QtTest 1.2
import "../../qmlcomponents" as Components

Item {
    width: 820; height: 680
    Components.PartitionPlanPopup {
        id: plan
        sourceName: "openhd-debian-x86-minimal.img"
        targetName: "SanDisk 57.3 GiB"
    }
    SignalSpy { id: confirmed; target: plan; signalName: "yes" }
    TestCase {
        name: "PartitionPlan"
        when: windowShown
        function cleanup() { plan.close(); confirmed.clear() }
        function test_plan_is_reviewed_before_confirmation() {
            plan.plan = ({ok: true, text: "Partition 1 - OPENHD: 64 MiB; kept from image\n\nCreate partition 5 - RECORDINGS (FAT32): 55.28 GiB"})
            plan.openPopup()
            tryCompare(plan, "opened", true)
            compare(confirmed.count, 0)
            verify(findChild(plan, "partitionPlanText").text.indexOf("RECORDINGS") >= 0)
            verify(plan.standardButton(Dialog.Ok).visible)
            mouseClick(plan.standardButton(Dialog.Cancel))
            compare(confirmed.count, 0)
        }
        function test_invalid_plan_cannot_start_writing() {
            plan.plan = ({ok: false, text: "Invalid image layout. Nothing has been written."})
            plan.openPopup()
            tryCompare(plan, "opened", true)
            verify(plan.standardButton(Dialog.Ok) === null)
            verify(plan.standardButton(Dialog.Close).visible)
            compare(confirmed.count, 0)
        }
        function test_layout_can_adjust_recordings_size() {
            plan.plan = ({
                ok: true,
                text: "",
                diskBytes: 1024 * 1024 * 1024,
                recordingsMaxBytes: 896 * 1024 * 1024,
                recordingsEditable: true,
                partitions: [
                    {number: 1, name: "EFI boot", filesystem: "FAT", mountPoint: "/boot/efi", action: "Kept from image", sizeBytes: 64 * 1024 * 1024, recordings: false},
                    {number: 2, name: "Linux filesystem", filesystem: "Image data", mountPoint: "/", action: "Kept from image", sizeBytes: 64 * 1024 * 1024, recordings: false},
                    {number: 3, name: "RECORDINGS", filesystem: "FAT32", mountPoint: "/recordings", action: "Created by ImageWriter", sizeBytes: 896 * 1024 * 1024, recordings: true}
                ]
            })
            plan.openPopup()
            tryCompare(plan, "opened", true)
            verify(plan.automaticPartitioning)
            compare(plan.selectedRecordingsBytes, 0)
            mouseClick(findChild(plan, "manualPartitioning"))
            verify(!plan.automaticPartitioning)
            compare(plan.selectedRecordingsBytes, 896 * 1024 * 1024)
            plan.selectedRecordingsMiB = 128
            compare(plan.selectedRecordingsBytes, 128 * 1024 * 1024)
            compare(plan.freeBytes(), 768 * 1024 * 1024)
            verify(findChild(plan, "recordingsSizeSlider").visible)
        }
    }
}
