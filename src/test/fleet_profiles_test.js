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
context.applyProfile(writer,{craftRole:'ground',craftPlatform:'rpi4',craftCamera:'USB',craftCamera2:'USB'});
assert.deepStrictEqual(JSON.parse(settings.initialParameterDefaults),{version:1,components:{}});
assert.strictEqual(settings.camera,''); assert.strictEqual(settings.camera2,'');
console.log(`PROFILE ROUND TRIP AND ${map.platforms.length} SHARED PLATFORMS PASSED`);
