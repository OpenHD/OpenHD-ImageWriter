import sys
with open(r'C:\Users\Raphael\OpenHD-FleetControl\src\types.ts', 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("'auto' | 'inav' | 'ardupilot' | 'px4'", "'auto' | 'inav' | 'ardupilot' | 'px4' | 'betaflight'")
text = text.replace("ownerAccountId: string;", "ownerAccountId: string;\n  settings?: Record<string, any>;")
with open(r'C:\Users\Raphael\OpenHD-FleetControl\src\types.ts', 'w', encoding='utf-8', newline='') as f:
    f.write(text)

with open(r'C:\Users\Raphael\OpenHD-FleetControl\server\store.ts', 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("'auto' | 'inav' | 'ardupilot' | 'px4'", "'auto' | 'inav' | 'ardupilot' | 'px4' | 'betaflight'")
text = text.replace("licenseId?: string;", "licenseId?: string;\n  settings?: Record<string, any>;")
with open(r'C:\Users\Raphael\OpenHD-FleetControl\server\store.ts', 'w', encoding='utf-8', newline='') as f:
    f.write(text)
