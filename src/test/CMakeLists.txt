cmake_minimum_required(VERSION 3.16)
project(OpenHDBackendTests LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt5 REQUIRED COMPONENTS Core)
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
    openhdbackend_test.cpp
    ../archivepathvalidator.cpp
    ../blockbatcher.cpp
    ../curlretrypolicy.cpp
    ../diskformatter.cpp
    ../drivesafetypolicy.cpp
    ../file_operations.cpp
    ${FILE_OPERATIONS_PLATFORM_SOURCE}
    ../ringbuffer.cpp
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
add_test(NAME openhd_backend_characterization COMMAND openhd_backend_tests)
