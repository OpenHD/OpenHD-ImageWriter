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
for (const page of ['ImageOptionsPage.qml', 'configure.qml']) {
    const source = fs.readFileSync(path.join(__dirname, '..', page), 'utf8');
    const group = {selectedVendor: {options: [{id: 'IMX708', valueWritten: '32'}]}};
    const context = {settingsMap: map, camera: 'IMX708', cameraResolution: '1920x1080@30',
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
}
assert.strictEqual(map.camera.firmwareDefaults['luckfox-pico'].resolution, '1280x720@60');
assert.strictEqual(map.cameraResolution.defaultByCameraValue['64'], '1920x1080@30');
assert(!map.initialFields.some(field => field.id === 'STREAMING_E'));
console.log('Camera defaults and restored selections passed for both QML screens');

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
