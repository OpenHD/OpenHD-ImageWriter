cmake_minimum_required(VERSION 3.16)
project(OpenHDBackendTests LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt5 REQUIRED COMPONENTS Core)
find_package(Qt5 REQUIRED COMPONENTS Gui Qml Quick)
qt5_add_resources(SETTINGS_TEST_RESOURCES settings-test.qrc)
if(NOT APPLE)
    find_package(OpenSSL REQUIRED COMPONENTS Crypto)
endif()

if(WIN32)
    set(FILE_OPERATIONS_PLATFORM_SOURCE ../windows/file_operations_windows.cpp)
elseif(APPLE)
    set(FILE_OPERATIONS_PLATFORM_SOURCE ../mac/file_operations_macos.cpp)
else()
    set(FILE_OPERATIONS_PLATFORM_SOURCE ../linux/file_operations_linux.cpp)
endif()

add_executable(openhd_backend_tests
    ${SETTINGS_TEST_RESOURCES}
    openhdbackend_test.cpp
    ../fatimagewriter.cpp
    ../dependencies/fatfs/ff.c
    ../dependencies/fatfs/ffunicode.c
    ../archivepathvalidator.cpp
    ../blockbatcher.cpp
    ../curlretrypolicy.cpp
    ../diskformatter.cpp
    ../drivesafetypolicy.cpp
    ../file_operations.cpp
    ${FILE_OPERATIONS_PLATFORM_SOURCE}
    ../ringbuffer.cpp
    ../rockchipfirmwarelayout.cpp
    ../writeprogresswatchdog.cpp
    ../openhdimagecustomizer.cpp
    ../openhdstorageselector.cpp
    ../certificatevalidator.cpp)
target_include_directories(openhd_backend_tests PRIVATE .. ../dependencies/cmcurl/include)
target_link_libraries(openhd_backend_tests PRIVATE Qt5::Core)
if(NOT APPLE)
    target_link_libraries(openhd_backend_tests PRIVATE OpenSSL::Crypto)
endif()

enable_testing()
add_executable(rockchip_device_tests rockchipdevice_test.cpp ../rockchipdevice.cpp)
target_include_directories(rockchip_device_tests PRIVATE ..)
target_link_libraries(rockchip_device_tests PRIVATE Qt5::Core)
if(WIN32)
    target_link_libraries(rockchip_device_tests PRIVATE setupapi uuid)
    target_compile_definitions(rockchip_device_tests PRIVATE _WIN32_WINNT=0x0601 WINVER=0x0601)
elseif(APPLE)
    target_link_libraries(rockchip_device_tests PRIVATE "-framework IOKit" "-framework CoreFoundation")
endif()
add_test(NAME rockchip_device_policy COMMAND rockchip_device_tests)
add_test(NAME openhd_backend_characterization COMMAND openhd_backend_tests)
add_executable(initialsettings_qml_test initialsettings_qml_test.cpp ${SETTINGS_TEST_RESOURCES})
set_target_properties(initialsettings_qml_test PROPERTIES AUTOMOC ON)
target_link_libraries(initialsettings_qml_test PRIVATE Qt5::Gui Qt5::Qml Qt5::Quick)
target_compile_definitions(initialsettings_qml_test PRIVATE INITIAL_SETTINGS_QML_PATH="${CMAKE_CURRENT_SOURCE_DIR}/../qmlcomponents/InitialSettingsPanel.qml")
add_test(NAME initialsettings_qml_contract COMMAND initialsettings_qml_test)
set_tests_properties(initialsettings_qml_contract PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
