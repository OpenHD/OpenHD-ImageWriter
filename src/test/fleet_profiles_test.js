const assert = require('assert');
const fs = require('fs');
const vm = require('vm');
const context = {}; vm.createContext(context);
vm.runInContext(fs.readFileSync(require.resolve('../qmlcomponents/FleetProfilesHelper.js'),'utf8').replace(/^\.pragma library\s*/,''),context);
const map=JSON.parse(fs.readFileSync(require.resolve('../../doc/openhd_settings_map.json'),'utf8'));
const settings={};
const writer={readResourceText:()=>JSON.stringify(map),getValue:key=>settings[key] || '',setSetting:(key,value)=>settings[key]=value};
context.getSettingsMap(writer);
for(const board of map.platforms) {
  assert.strictEqual(context.platformForHardware(board.id).sbc,board.sbc);
  context.applyProfile(writer,{craftId:'craft-1',craftRole:board.roles[0],craftPlatform:board.id,craftHardware:board.label,
    craftCamera:'USB',craftInitialDefaults:'{"version":1,"components":{"100":{"AIR_RECORDING_E":2}}}',craftWriterSettings:'{"disableEthernetLink":false}'});
  assert.strictEqual(settings.platform,board.id);
  assert.strictEqual(settings.sbc,board.sbc);
  assert.strictEqual(JSON.parse(settings.initialParameterDefaults).components['100'].AIR_RECORDING_E,2);
  assert.strictEqual(settings.disableEthernetLink,false);
}
assert.strictEqual(context.platformForHardware('Raspberry Pi (Pi 4 / Pi 5 / CM4 / Zero 2W)'),null);
assert.strictEqual(context.platformForHint('openhd-rpi5-bullseye.img').id,'rpi5');
assert.strictEqual(context.platformForHint('openhd-rpi-bullseye.img'),null);
for (const name of ['openhd-image-luckfox-pico-ultra-w(1).zip', 'openhd-pico-rv1106-sd.zip', 'RV1106', 'luckfox-pico'])
  assert.strictEqual(context.isRv1106Image(name),true,name);
for (const name of ['firmware.zip', 'openhd-x21.zip', 'luckfox-lyra', 'rpi4'])
  assert.strictEqual(context.isRv1106Image(name),false,name);
assert.deepStrictEqual(Array.from(context.platformForHardware('rv1106').roles),['air']);
assert.strictEqual(context.isRv1106Device({device:'rockusb:board',usbVendorId:0x2207,usbProductId:0x110c}),true);
assert.strictEqual(context.isRv1106Device({device:'rockusb:board',usbVendorId:0x2207,usbProductId:0x110f}),false);
assert.strictEqual(context.isRv1106Device({device:'disk',usbVendorId:0x2207,usbProductId:0x110c}),false);
assert.strictEqual(context.isRv1106Device({device:'rockusb:board'}),false);
// Exercise the actual write entry point with a saved Ground profile present.
const flashQml=fs.readFileSync(require.resolve('../flash.qml'),'utf8');
const writeEntry=flashQml.slice(flashQml.indexOf('    function startWriteNow()'),
  flashQml.indexOf('\n    ColumnLayout {',flashQml.indexOf('    function startWriteNow()')));
function tryWrite(fixedDefaults, ethernet=false, configured=false) {
  const saved={bootType:'Ground',camera:configured?'MIS5001':'USB',camera2:'USB',initialParameterDefaults:'{"version":1,"components":{"100":{"AIR_RECORDING_E":2}}}'};
  let started=false;
  const ui={usesRv1106Defaults:fixedDefaults,picoEthernetLink:ethernet,fleetControlSignedIn:true,useProfileSettings:true,
    fleetControlProfileName:fixedDefaults?'old-ground-profile':'',optionsPage:{configurationApplied:configured},
    FleetProfilesHelper:{loadProfiles:()=>{throw Error('RV1106 must not load a saved profile');}},
    imageWriter:{setSetting:(key,value)=>saved[key]=value,getBoolSetting:()=>false,
      setVerifyEnabled:()=>{},startWrite:()=>started=true},
    resetOpenHdSettingsForNewImage:()=>{for(const key of Object.keys(saved)) delete saved[key];},
    rockchipFinalizationFallback:{stop:()=>{}},resetDownloadTracking:()=>{},
    qsTr:text=>text,console:{log:()=>{}},reviewingOperation:false};
  for(const id of ['langbar','writebutton','cancelwritebutton','cancelverifybutton','progressText','osbutton','dstbutton']) ui[id]={};
  ui.progressBar={Material:{}};
  vm.runInNewContext(writeEntry+'\nstartWriteNow()',ui);
  return {started,saved,ui};
}
const fixedWrite=tryWrite(true);
assert.strictEqual(fixedWrite.started,true);
assert.strictEqual(fixedWrite.saved.bootType,'Air');
assert.strictEqual(fixedWrite.saved.platform,'luckfox-pico');
assert.strictEqual(fixedWrite.saved.useSettings,false);
assert.strictEqual(fixedWrite.saved.camera,undefined);
assert.strictEqual(fixedWrite.saved.camera2,undefined);
assert.strictEqual(fixedWrite.saved.disableEthernetLink,true);
const ethernetWrite=tryWrite(true,true);
assert.strictEqual(ethernetWrite.started,true);
assert.strictEqual(ethernetWrite.saved.useSettings,true);
assert.strictEqual(ethernetWrite.saved.disableEthernetLink,false);
assert.strictEqual(ethernetWrite.saved.picoUsbEthernetOnly,true);
assert.strictEqual(ethernetWrite.saved.camera,undefined);
const picoConfigured=tryWrite(true,true,true);
assert.strictEqual(picoConfigured.saved.camera,'MIS5001');
assert.strictEqual(JSON.parse(picoConfigured.saved.initialParameterDefaults).components['100'].AIR_RECORDING_E,2);
assert.strictEqual(picoConfigured.saved.useSettings,true);
assert.strictEqual(picoConfigured.saved.picoUsbEthernetOnly,false);
const configurableWrite=tryWrite(false);
assert.strictEqual(configurableWrite.started,false);
assert.strictEqual(configurableWrite.ui.reviewingOperation,true);
context.applyProfile(writer,{craftRole:'ground',craftPlatform:'rpi4',craftCamera:'USB',craftCamera2:'USB'});
assert.deepStrictEqual(JSON.parse(settings.initialParameterDefaults),{version:1,components:{}});
assert.strictEqual(settings.camera,''); assert.strictEqual(settings.camera2,'');
console.log(`PROFILE ROUND TRIP AND ${map.platforms.length} SHARED PLATFORMS PASSED`);
