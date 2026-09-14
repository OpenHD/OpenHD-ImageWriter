const fs = require('fs');
function fix(p, replaceObj) {
  let text = fs.readFileSync(p, 'utf8');
  for (const [k, v] of Object.entries(replaceObj)) {
    text = text.replace(k, v);
  }
  fs.writeFileSync(p, text);
}
fix('C:/Users/Raphael/OpenHD-FleetControl/server/store.ts', {
  "'auto' | 'inav' | 'ardupilot' | 'px4'": "'auto' | 'inav' | 'ardupilot' | 'px4' | 'betaflight'",
  "licenseId?: string;": "licenseId?: string;\n  settings?: Record<string, any>;"
});
fix('C:/Users/Raphael/OpenHD-FleetControl/src/types.ts', {
  "'auto' | 'inav' | 'ardupilot' | 'px4'": "'auto' | 'inav' | 'ardupilot' | 'px4' | 'betaflight'",
  "ownerAccountId: string;": "ownerAccountId: string;\n  settings?: Record<string, any>;"
});
