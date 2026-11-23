const assert = require('assert');
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const map = JSON.parse(fs.readFileSync(path.join(__dirname, '../../doc/openhd_settings_map.json')));
function method(source, name) {
    const start = source.indexOf('function ' + name + '(');
    assert(start >= 0, name);
    let end = source.indexOf('{', start), depth = 1;
    while (depth) {
        ++end;
        if (source[end] === '{') ++depth;
        if (source[end] === '}') --depth;
    }
    return source.slice(start, end + 1);
}
const fleetHelper = fs.readFileSync(path.join(__dirname, '../qmlcomponents/FleetProfilesHelper.js'), 'utf8');
const zero3wHdmiModes = [
    ['rock3-hdmi-csi', 'TC358743 (2 CSI lanes)', '90', ['1280x720@30', '1280x720@60', '1920x1080@30']],
    ['rock3-hdmi-csi', 'TC358743 (4 CSI lanes)', '99', ['1280x720@30', '1280x720@60', '1920x1080@30', '1920x1080@60']],
    ['radxa-rk628', 'Radxa HDMI to CSI (RK628H)', '100', ['1280x720@30', '1280x720@60', '1920x1080@30', '1920x1080@60']],
];
const helper = vm.createContext({});
vm.runInContext(method(fleetHelper, 'requiresCameraSelection'), helper);
for (const page of ['ImageOptionsPage.qml', 'configure.qml']) {
    const source = fs.readFileSync(path.join(__dirname, '..', page), 'utf8');
    const group = {selectedVendor: {options: [{id: 'IMX708', valueWritten: '32'}]}};
    const context = {settingsMap: map, FleetProfilesHelper: helper, camera: 'IMX708', cameraResolution: '1920x1080@30',
        rebuilding: false, cameraGroup: group, cameraLayout: group,
        rebuildSecondaryCameraOptions() {}, firmwareCameraLabel: () => 'Firmware camera',
        firmwareResolutionLabel: () => 'Firmware resolution'};
    Object.defineProperty(group, 'rebuilding', {get: () => context.rebuilding});
    function model(selector, changed) {
        const entries = [];
        return {get count() {return entries.length;}, get: i => entries[i],
            clear() {entries.length = 0; selector.currentIndex = -1; changed();},
            append(entry) {entries.push(entry); if (selector.currentIndex < 0) {selector.currentIndex = 0; changed();}}};
    }
    context.cameraSelector = {currentIndex: -1};
    context.cameraResolutionSelector = {currentIndex: -1};
    context.cameraOptionsModel = model(context.cameraSelector, () => {
        if (!context.rebuilding && context.cameraOptionsModel.count && context.cameraSelector.currentIndex >= 0)
            context.camera = context.cameraOptionsModel.get(context.cameraSelector.currentIndex).cameraId || '';
    });
    context.cameraResolutionOptionsModel = model(context.cameraResolutionSelector, () => {
        if (!context.rebuilding && context.cameraResolutionOptionsModel.count && context.cameraResolutionSelector.currentIndex >= 0)
            context.cameraResolution = context.cameraResolutionOptionsModel.get(context.cameraResolutionSelector.currentIndex).value;
    });
    vm.createContext(context);
    for (const name of ['normalizeCameraValueForResolutionLookup', 'resolutionListForCameraValue',
                        'rebuildPrimaryResolutionOptions', 'rebuildCameraOptions'])
        vm.runInContext(method(source, name), context);
    context.rebuildCameraOptions();
    assert.strictEqual(context.camera, 'IMX708', page + ': restored camera lost');
    assert.strictEqual(context.cameraResolution, '1920x1080@30', page + ': restored resolution lost');
    context.camera = '';
    context.cameraResolution = '';
    context.rebuildCameraOptions();
    assert.strictEqual(context.cameraSelector.currentIndex, 0);
    assert.strictEqual(context.cameraOptionsModel.get(0).displayText, 'Firmware camera');
    assert.strictEqual(context.cameraResolutionOptionsModel.get(0).label, 'Firmware resolution');
    assert.strictEqual(context.camera, '', 'Firmware camera must not be overridden');
    assert.strictEqual(context.cameraResolution, '', 'Firmware resolution must not be overridden');
    context.camera = 'IMX708';
    context.rebuildCameraOptions();
    assert.strictEqual(context.cameraResolution, map.cameraResolution.defaultByCameraValue['32']);

    const zero3w = map.camera.sbcGroups.find(group => group.sbc.includes('zero3w'));
    group.selectedVendor = zero3w.vendors[0];
    const modes = new Map([
        ['OV5647', false], ['IMX519', true], ['IMX708', true], ['IMX462 Pivariety', false],
        ['IMX219', false], ['IMX462', true],
    ]);
    assert.deepStrictEqual(group.selectedVendor.options.filter(option => !option.hidden).map(option => option.id), [...modes.keys()]);
    for (const [camera, supports120] of modes) {
        context.camera = camera;
        context.cameraResolution = '1280x720@120';
        context.rebuildCameraOptions();
        assert.strictEqual(context.cameraOptionsModel.count, modes.size);
        assert.strictEqual(context.camera, camera);
        assert.strictEqual(context.cameraResolution === '1280x720@120', supports120);
    }
    context.camera = 'VEYE';
    context.rebuildCameraOptions();
    assert.strictEqual(context.camera, 'OV5647');
    assert.strictEqual(context.cameraOptionsModel.get(0).displayText, 'Raspberry Pi Camera v1 (OV5647)');

    for (const vendorId of ['rock3-hdmi-csi', 'radxa-rk628']) {
        const vendor = zero3w.vendors.find(vendor => vendor.id === vendorId);
        assert.strictEqual(vendor.requiresCameraSelection, true);
        // Configure also reads manifests written before the selection flag was added.
        group.selectedVendor = {...vendor, requiresCameraSelection: undefined};
        context.camera = 'IMX462';
        context.cameraResolution = '1920x1080@60';
        context.rebuildCameraOptions();
        assert.deepStrictEqual(Array.from({length: context.cameraOptionsModel.count},
            (_, idx) => context.cameraOptionsModel.get(idx).cameraId), vendor.options.map(option => option.id));
        assert.strictEqual(context.camera, vendor.options[0].id);
        assert.strictEqual(context.cameraResolution, map.cameraResolution.defaultByCameraValue[vendor.options[0].valueWritten]);
    }

    group.selectedVendor = zero3w.vendors[0];
    vm.runInContext(method(fleetHelper, 'usesHdmiEdid'), context);
    assert(!context.usesHdmiEdid(map, group.selectedVendor, 'OV5647'));
    for (const [vendorId, name, cameraId, resolutions] of zero3wHdmiModes) {
        group.selectedVendor = zero3w.vendors.find(vendor => vendor.id === vendorId);
        context.camera = name;
        context.cameraResolution = '1280x720@30';
        context.rebuildCameraOptions();
        assert(context.usesHdmiEdid(map, group.selectedVendor, context.camera));
        assert.strictEqual(context.cameraOptionsModel.get(context.cameraSelector.currentIndex).value, cameraId);
        assert.deepStrictEqual(Array.from({length: context.cameraResolutionOptionsModel.count},
            (_, idx) => context.cameraResolutionOptionsModel.get(idx).value), resolutions, page + ': ' + name);
        assert.strictEqual(context.cameraResolution, '1280x720@30');
    }
}
assert.strictEqual(map.camera.firmwareDefaults['luckfox-pico'].resolution, '1280x720@60');
assert.strictEqual(map.cameraResolution.defaultByCameraValue['64'], '1920x1080@30');
assert(!map.initialFields.some(field => field.id === 'STREAMING_E'));
console.log('Camera defaults and restored selections passed for both QML screens');

const fleetSource = fs.readFileSync(path.join(__dirname, '../qmlcomponents/FleetControlPage.qml'), 'utf8');
const fleet = {
    FleetProfilesHelper: helper,
    editorVendors: map.camera.sbcGroups.find(group => group.sbc.includes('zero3w')).vendors,
    vendorDropdown: {currentIndex: 0},
    cameraDropdown: {currentIndex: -1},
    savedCamera: 'IMX462 Pivariety',
    refreshEditorSecondaryCameras() {},
    refreshEditorResolutions() {},
};
vm.createContext(fleet);
vm.runInContext(method(fleetSource, 'refreshEditorCameras'), fleet);
vm.runInContext(method(fleetSource, 'selectedEditorCamera'), fleet);
fleet.refreshEditorCameras(true);
assert.strictEqual(fleet.cameraDropdown.model.length, 6);
assert.strictEqual(fleet.selectedEditorCamera(), 'IMX462 Pivariety');
fleet.refreshEditorCameras(false);
assert.strictEqual(fleet.selectedEditorCamera(), 'OV5647');
for (const vendorId of ['rock3-hdmi-csi', 'radxa-rk628']) {
    fleet.vendorDropdown.currentIndex = fleet.editorVendors.findIndex(vendor => vendor.id === vendorId);
    fleet.refreshEditorCameras(false);
    const options = fleet.editorVendors[fleet.vendorDropdown.currentIndex].options;
    assert.strictEqual(fleet.cameraDropdown.model.length, options.length);
    assert.strictEqual(fleet.selectedEditorCamera(), options[0].id);
}

const flashSource = fs.readFileSync(path.join(__dirname, '../flash.qml'), 'utf8');
for (const luckfox of [true, false]) {
    let opened = 0;
    const context = {
        selectedImageRequiresRockchip: false, usesRv1106Defaults: luckfox,
        FleetProfilesHelper: {isRv1106Device: () => luckfox},
        imageWriter: {stopDriveListPolling() {}, setDst() {}, readyToWrite: () => true},
        writebutton: {}, dstbutton: {},
        optionsPage: {configurationApplied: false, visible: false,
            openPage() { ++opened; this.visible = true; }, close() { this.visible = false; }}
    };
    vm.createContext(context);
    vm.runInContext(method(flashSource, 'selectDstItem'), context);
    vm.runInContext(method(flashSource, 'navigateBack'), context);
    context.selectDstItem({device: 'rockusb://test', size: 128000000, description: 'Test board'});
    assert.strictEqual(context.reviewingOperation, true);
    assert.strictEqual(opened, luckfox ? 1 : 0, 'Luckfox must open full settings after target selection');
    if (luckfox) {
        context.navigateBack();
        assert.strictEqual(context.optionsPage.visible, false);
        assert.strictEqual(context.reviewingOperation, true, 'Back from settings must return to review');
        context.optionsPage.configurationApplied = true;
        context.selectDstItem({device: 'rockusb://test', size: 128000000, description: 'Test board'});
        assert.strictEqual(opened, 1, 'Saved settings must not be reopened automatically');
    }
}
console.log('Luckfox full settings entry and return to review passed');
