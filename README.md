# OpenHD ImageWriter


OpenHD ImageWriter

The OpenHD ImageWriter is an image flashing untillity based on https://github.com/raspberrypi/rpi-imager/

It's goal is to ease installation of OpenHD images and to integrate initial settings, which are necessary in 2.2-evo builds.


## License

The main code of the Imaging Utility is made available under the terms of the Apache license.
See license.txt and files in "src/dependencies" folder for more information about the various open source licenses that apply to the third-party dependencies used such as Qt, libarchive, drivelist, mountutils and libcurl.
For the embedded (netboot) build see also "embedded/legal-info" for more information about the extra system software included in that.

## How to rebuild

### Arch Linux / AUR

The repository includes an AUR recipe for `openhdimagewriter-git`, following
the latest `dev-branch` source. It replaces `openhdimagewriter` if installed.
This recipe is prepared for submission; availability on the AUR must be
confirmed before using an AUR helper.

Build on Arch Linux as a regular user:

```sh
sudo pacman -S --needed base-devel git
git clone https://github.com/OpenHD/OpenHD-ImageWriter.git
cd OpenHD-ImageWriter
makepkg -si
```

See [AUR publication instructions](doc/aur.md) for the initial submission and
maintenance process.

### Continuous integration

All builds and backend tests run from `.github/workflows/build.yml`: Ubuntu
packages, the Windows installer, Intel and Apple Silicon macOS DMGs, and an
Arch Linux package with AUR submission files. Pull requests and manual runs
also build all platforms. Cloudsmith uploads run only on pushes to `release`
and `dev-release`.

### Debian/Ubuntu Linux

#### Get dependencies

Install the build dependencies:

```
sudo apt install --no-install-recommends build-essential devscripts debhelper cmake git libarchive-dev libcurl4-openssl-dev \
    qtbase5-dev qtbase5-dev-tools qtdeclarative5-dev libqt5svg5-dev qttools5-dev libssl-dev \
    qml-module-qtquick2 qml-module-qtquick-controls2 qml-module-qtquick-layouts qml-module-qtquick-templates2 qml-module-qtquick-window2 qml-module-qtgraphicaleffects
```

#### Get the source

```
git clone --depth 1 https://github.com/OpenHD/OpenHD-ImageWriter/
```


#### Build the Debian package

```
cd OpenHD-ImageWriter
debuild -uc -us
```

debuild will compile everything, create a .deb package and put it in the parent directory.
Can install it with apt:

```
cd ..
sudo apt install ./openhdimagewriter*.deb
```

It should create an icon in the start menu under "Utilities" or "Accessories".
The imaging utility will normally be run as regular user, and will call udisks2 over DBus to perform privileged operations like opening the disk device for writing.
If udisks2 is not functional on your Linux distribution, you can alternatively start it as "root" with sudo and similar tools.


### Windows

#### Get dependencies

- Get the Qt online installer from: https://www.qt.io/download-open-source
During installation, choose a Qt 5.x with Mingw32 32-bit toolchain and CMake.

- If using the official Qt distribution that does NOT have schannel (Windows native SSL library) support, compile OpenSSL libraries ( https://wiki.qt.io/Compiling_OpenSSL_with_MinGW ) and copy the libssl/crypto DLLs to C:\qt\5.x\mingw73_32\bin  the include files to C:\qt\5.x\mingw73_32\include and the import library files to C:\qt\5.x\mingw73_32\lib

- One important step is to pray to the code gods, it never have been easy to compile QT-stuff;)

- For building installer get Nullsoft scriptable install system: https://nsis.sourceforge.io/Download

- Public Windows builds must be Authenticode-signed with a publicly trusted code
  signing certificate. Local builds can remain unsigned.

  GitHub Actions signs both the application executable and the final NSIS
  installer when these repository secrets are configured:

  - `WINDOWS_SIGNING_CERTIFICATE_BASE64`: base64-encoded PKCS#12 (`.pfx`) file
  - `WINDOWS_SIGNING_CERTIFICATE_PASSWORD`: password for that file

  If neither secret is present, CI continues to produce an unsigned artifact
  for pull requests and forks. If only one is present, the Windows job fails to
  prevent an accidentally incomplete signing configuration.


#### Building

Building can be done manually using the command-line, using "cmake", "make", etc., but if you are not that familar with setting up a proper Windows build environment (setting paths, etc.), it is easiest to use the Qt creator GUI instead.

- Download source .zip from github and extract it to a folder on disk
- Open src/CMakeLists.txt in Qt creator.
- For builds you distribute to others, make sure you choose "Release" in the toolchain settings and not the debug flavour.
- Menu "Build" -> "Build all"
- Result will be in build_openhdimagewriter_someversion
- Go to the BUILD folder, right click on the .nsi script "Compile NSIS script", to create installer.

Note: the CMake integration in Qt Creator is a bit flaky at times. If you made any custom changes to the CMakeLists.txt file and it subsequently gets in an endless loop where it never finishes the "configures" stage while re-processing the file, delete "build_openhdimagewriter_someversion" directory and try again.

### Mac OS X

#### Get dependencies

- Get the Qt online installer from: https://www.qt.io/download-open-source
During installation, choose a Qt 5.x edition and CMake.
- For creating a .DMG for distribution you can use an utility like: https://github.com/sindresorhus/create-dmg
- It is assumed you have an Apple developer subscription, and already have a "Developer ID" code signing certificate for distribution outside the Mac Store. (Privileged apps are not allowed in the Mac store)

#### Building

- Download source .zip from github and extract it to a folder on disk
- Start Qt Creator (may need to start "finder" navigate to home folder using the "Go" menu, and find Qt folder to start it manually as it may not have created icon in Applications), and open src/CMakeLists.txt
- Menu "Build" -> "Build all"
- Result will be in build_openhdimagewriter_someversion
- For distribution to others: code sign the .app, create a DMG, code sign the DMG, submit it for notarization to Apple and staple the notarization ticket to the DMG.

E.g.:

```
cd build-openhdimagewriter-Desktop_Qt_5_14_1_clang_64bit-Release/
codesign --deep --force --verify --verbose --sign "YOUR KEYID" --options runtime openhdimagewriter.app
mv openhdimagewriter.app "Raspberry Pi Imager.app"
create-dmg Raspberry\ Pi\ Imager.app
mv Raspberry\ Pi\ Imager\ .dmg imager.dmg
xcrun altool --notarize-app -t osx -f imager.dmg --primary-bundle-id="org.raspberrypi.imagingutility" -u YOUR-EMAIL-ADDRESS -p YOUR-APP-SPECIFIC-APPLE-PASSWORD -itc_provider TEAM-ID-IF-APPLICABLE
xcrun stapler staple imager.dmg
```

## Other notes

### Debugging

On Linux and Mac the application will print debug messages to console by default if started from console.
On Windows start the application with the command-line option --debug to let it open a console window.

### Custom repository

If the application is started with "--repo [your own URL]" it will use a custom image repository.
So can simply create another 'start menu shortcut' to the application with that parameter to use the application with your own images.

### Telemetry

Is disabled, since I don't like it.

### Advanced options

When using the app, press <kbd>CTRL</kbd> + <kbd>SHIFT</kbd> + <kbd>X</kbd> to reveal the **Advanced options** dialog.

In here, you can specify several things you would otherwise set in the boot configuration files. For example, you can enable SSH, set the Wi-Fi login, and specify your locale settings for the system image.
