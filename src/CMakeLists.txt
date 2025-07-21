# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2020 Raspberry Pi Ltd
# Copyright (C) 2024 OpenHD

cmake_minimum_required(VERSION 3.22)
OPTION (ENABLE_CHECK_VERSION "Check for version updates" ON)
OPTION (ENABLE_TELEMETRY "Enable sending telemetry" ON)

# Set minimum policy version for third-party dependencies (CMake 4.0+ feature)
if(CMAKE_VERSION VERSION_GREATER_EQUAL "4.0")
    set(CMAKE_POLICY_VERSION_MINIMUM "3.5" CACHE STRING "Minimum policy version for third-party dependencies")
endif()

# Set policy for compatibility with older CMake versions
if(POLICY CMP0077)
    cmake_policy(SET CMP0077 NEW)
endif()

# Modern FetchContent usage with FetchContent_MakeAvailable()
# Note: Dependencies are built as needed with proper target dependencies

# OVERRIDE_FIND_PACKAGE is only available in CMake 3.24+
# Create a variable to conditionally use it
if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.24")
    set(USE_OVERRIDE_FIND_PACKAGE "OVERRIDE_FIND_PACKAGE")
else()
    set(USE_OVERRIDE_FIND_PACKAGE "")
endif()

set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "Which macOS architectures to build for")

project(OpenHDImageWriter LANGUAGES CXX C)
set(IMAGER_VERSION_MAJOR 2)
set(IMAGER_VERSION_MINOR 0)
set(IMAGER_VERSION_PATCH 6)
set(IMAGER_VERSION_STR "${IMAGER_VERSION_MAJOR}.${IMAGER_VERSION_MINOR}.${IMAGER_VERSION_PATCH}")
set(IMAGER_VERSION_CSV "${IMAGER_VERSION_MAJOR},${IMAGER_VERSION_MINOR},${IMAGER_VERSION_PATCH},0")
# Version definitions will be added to target later
set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# You _must_ set your Qt6 root for the build to progress.
set(Qt6_ROOT "D:/Qt/6.6.0/msvc2019_64" CACHE PATH "Your Qt6 root path")

if (WIN32)
    set(MINGW64_ROOT "" CACHE PATH "Your MinGW64 root path, likely provided by QtCreator")
    set(IMAGER_SIGNED_APP OFF CACHE BOOL "Sign Imager and its installer as part of the build. Requires a valid Code Signing certificate.")
endif()

if (APPLE)
    set(IMAGER_SIGNED_APP OFF CACHE BOOL "Perform signing of the Imager .app as part of the build")
    set(IMAGER_SIGNING_IDENTITY "" CACHE STRING "The Developer Identity to use for signing.")
    set(IMAGER_NOTARIZE_APP OFF CACHE BOOL "Perform notarization of the Imager .dmg as part of the build")
    set(IMAGER_NOTARIZE_KEYCHAIN_PROFILE "" CACHE STRING "The name of the Keychain item containing your notarization credentials")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "11" CACHE STRING "" FORCE)
endif(APPLE)

# Bundled code will occasionally use identical options - eg, BUILD_TESTING.
set(BUILD_TESTING OFF)
set(BUILD_STATIC_LIBS ON)
set(BUILD_SHARED_LIBS OFF)

include(FetchContent)

# Bundled liblzma
set(LIBLZMA_VERSION "5.8.1")
FetchContent_Declare(xz
    GIT_REPOSITORY https://github.com/tukaani-project/xz.git
    GIT_TAG v${LIBLZMA_VERSION}
    ${USE_OVERRIDE_FIND_PACKAGE}
)
set(XZ_MICROLZMA_DECODER OFF CACHE BOOL "" FORCE)
set(XZ_MICROLZMA_ENCODER OFF CACHE BOOL "" FORCE)
set(XZ_LZIP_DECODER OFF CACHE BOOL "" FORCE)
set(XZ_ENABLE_SANDBOX OFF CACHE BOOL "" FORCE)
set(XZ_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(XZ_ENABLE_DOXYGEN OFF CACHE BOOL "" FORCE)
set(XZ_NLS OFF CACHE BOOL "" FORCE)
set(XZ_DECODERS
    lzma1
    lzma2
    delta
)
set(XZ_ENCODERS
    lzma1
    lzma2
    delta
)
set(CREATE_LZMA_SYMLINKS OFF CACHE BOOL "" FORCE)
set(CREATE_XZ_SYMLINKS OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(xz)
unset(XZ_MICROLZMA_DECODER)
unset(XZ_MICROLZMA_ENCODER)
unset(XZ_LZIP_DECODER)
unset(XZ_ENABLE_SANDBOX)
unset(XZ_BUILD_SHARED_LIBS)
unset(XZ_ENABLE_DOXYGEN)
unset(CREATE_LZMA_SYMLINKS)
unset(CREATE_XZ_SYMLINKS)
# Set LZMA variables for compatibility (avoid FORCE unless necessary)
set(LIBLZMA_FOUND true CACHE BOOL "LZMA library found")
set(LIBLZMA_INCLUDE_DIR ${xz_SOURCE_DIR}/src/liblzma/api CACHE PATH "LZMA include directory")
set(LIBLZMA_INCLUDE_DIRS ${xz_SOURCE_DIR}/src/liblzma/api CACHE PATH "LZMA include directories")
set(LIBLZMA_LIBRARY liblzma CACHE STRING "LZMA library target")
set(LIBLZMA_LIBRARIES liblzma CACHE STRING "LZMA libraries")
set(LIBLZMA_HAS_AUTO_DECODER true CACHE BOOL "LZMA has auto decoder")
set(LIBLZMA_HAS_EASY_ENCODER true CACHE BOOL "LZMA has easy encoder")
set(LIBLZMA_HAS_LZMA_PRESET true CACHE BOOL "LZMA has preset")

# Bundled zstd
set(ZSTD_VERSION "1.5.7")
FetchContent_Declare(zstd
    GIT_REPOSITORY https://github.com/facebook/zstd.git
    GIT_TAG v${ZSTD_VERSION}
    SOURCE_SUBDIR build/cmake
    ${USE_OVERRIDE_FIND_PACKAGE}
)
set(ZSTD_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_STATIC ON CACHE BOOL "" FORCE)
set(ZSTD_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_DICTBUILDER OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(zstd)
unset(ZSTD_BUILD_PROGRAMS)
unset(ZSTD_BUILD_SHARED)
unset(ZSTD_BUILD_STATIC)
unset(ZSTD_BUILD_TESTS)
unset(ZSTD_BUILD_DICTBUILDER)

# Create modern namespace target for ZSTD
if(TARGET libzstd_static AND NOT TARGET zstd::libzstd_static)
    add_library(zstd::libzstd_static ALIAS libzstd_static)
endif()

# Set ZSTD variables for compatibility
set(ZSTD_FOUND true CACHE BOOL "ZSTD library found")
set(Zstd_VERSION ${ZSTD_VERSION} CACHE STRING "ZSTD version")
set(Zstd_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/_deps/zstd-src/lib CACHE PATH "ZSTD include directory")
set(ZSTD_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/_deps/zstd-src/lib CACHE PATH "ZSTD include directory")
set(Zstd_INCLUDE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/_deps/zstd-src/lib CACHE PATH "ZSTD include directories")
set(ZSTD_INCLUDE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/_deps/zstd-src/lib CACHE PATH "ZSTD include directories")
set(Zstd_LIBRARIES libzstd_static CACHE STRING "ZSTD libraries")
# Note: Using modern namespace target zstd::libzstd_static instead of ZSTD_LIBRARIES variable
set(ZSTD_LIBRARY libzstd_static CACHE STRING "ZSTD library target")

if (NOT APPLE)
    # Bundled zlib (Windows/Linux only)
    set(ZLIB_VERSION "1.4.1.1")
    set(ZLIB_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(ZLIB_BUILD_SHARED OFF CACHE BOOL "" FORCE)
    set(ZLIB_BUILD_STATIC ON CACHE BOOL "" FORCE)
    set(ZLIB_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(SKIP_INSTALL_ALL ON CACHE BOOL "" FORCE)
    FetchContent_Declare(zlib
        GIT_REPOSITORY https://github.com/madler/zlib.git
        GIT_TAG 5a82f71ed1dfc0bec044d9702463dbdf84ea3b71 # v1.4.1.1
        ${USE_OVERRIDE_FIND_PACKAGE}
    )
    FetchContent_MakeAvailable(zlib)
    unset(ZLIB_BUILD_EXAMPLES)
    unset(ZLIB_BUILD_SHARED)
    unset(ZLIB_BUILD_STATIC)
    unset(ZLIB_BUILD_TESTS)
    unset(SKIP_INSTALL_ALL)
    set(ZLIB_USE_STATIC_LIBS ON CACHE BOOL "Use static ZLIB")
    set(ZLIB_ROOT ${zlib_SOURCE_DIR} CACHE PATH "ZLIB root directory")

    # Set ZLIB variables for compatibility
    set(ZLIB_INCLUDE_DIR ${zlib_SOURCE_DIR} CACHE PATH "ZLIB include directory")
    set(ZLIB_INCLUDE_DIRS ${zlib_SOURCE_DIR};${zlib_BINARY_DIR} CACHE PATH "ZLIB include directories")
    set(ZLIB_FOUND TRUE CACHE BOOL "ZLIB library found")
    set(ZLIB_LIBRARY zlibstatic CACHE STRING "ZLIB library target")
    set(ZLIB_LIBRARIES zlibstatic CACHE STRING "ZLIB libraries")

    # Create ZLIB::ZLIB alias target pointing to the actual zlibstatic target
    # This lets CMake handle the actual library path and build dependencies automatically
    if(TARGET zlibstatic)
        add_library(ZLIB::ZLIB ALIAS zlibstatic)
    endif()
else()
    # Use system zlib on macOS to avoid target conflicts
    find_package(ZLIB REQUIRED)
    if(ZLIB_FOUND AND NOT TARGET ZLIB::ZLIB)
        add_library(ZLIB::ZLIB INTERFACE IMPORTED)
        set_target_properties(ZLIB::ZLIB PROPERTIES
            INTERFACE_LINK_LIBRARIES "${ZLIB_LIBRARIES}"
            INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIRS}")
    endif()
endif()

# Bundled libarchive
set(ENABLE_WERROR OFF CACHE BOOL "")
set(ENABLE_INSTALL OFF CACHE BOOL "")
set(ENABLE_TEST OFF CACHE BOOL "")
set(ENABLE_CNG OFF CACHE BOOL "")
set(ENABLE_MBEDTLS OFF CACHE BOOL "")
set(ENABLE_NETTLE OFF CACHE BOOL "")
set(ENABLE_OPENSSL OFF CACHE BOOL "")
if(APPLE)
    # Use system zlib on macOS
    set(ENABLE_ZLIB ON CACHE BOOL "")
else()
    # Use bundled zlib on Windows/Linux
    set(ENABLE_ZLIB ON CACHE BOOL "")
endif()
set(ENABLE_BZip2 OFF CACHE BOOL "")
set(ENABLE_LZ4 OFF CACHE BOOL "")
set(ENABLE_LZO OFF CACHE BOOL "")
set(ENABLE_LIBB2 OFF CACHE BOOL "")
set(ENABLE_LIBXML2 OFF CACHE BOOL "")
set(ENABLE_EXPAT OFF CACHE BOOL "")
set(ENABLE_PCREPOSIX OFF CACHE BOOL "")
set(ENABLE_PCRE2POSIX OFF CACHE BOOL "")
set(ENABLE_LIBGCC OFF CACHE BOOL "")
set(ENABLE_TAR OFF CACHE BOOL "")
set(ENABLE_CPIO OFF CACHE BOOL "")
set(ENABLE_CAT OFF CACHE BOOL "")
set(BUILD_SHARED_LIBS OFF CACHE BOOL "")
set(ARCHIVE_BUILD_STATIC_LIBS ON CACHE BOOL "")
set(ARCHIVE_BUILD_EXAMPLES OFF CACHE BOOL "")
set(ENABLE_ZSTD ON CACHE BOOL "")
set(ENABLE_LZMA ON CACHE BOOL "")
# Point libarchive to our bundled LZMA
set(LIBLZMA_INCLUDE_DIR ${xz_SOURCE_DIR}/src/liblzma/api CACHE PATH "LZMA include for libarchive")
set(LIBLZMA_LIBRARY liblzma CACHE STRING "LZMA library for libarchive")
set(POSIX_REGEX_LIB "libc" CACHE STRING "Regex library for libarchive")
set(LIBARCHIVE_VERSION "3.8.1")

FetchContent_Declare(libarchive
    GIT_REPOSITORY https://github.com/libarchive/libarchive.git
    GIT_TAG v${LIBARCHIVE_VERSION}
    ${USE_OVERRIDE_FIND_PACKAGE}
)
FetchContent_MakeAvailable(libarchive)

# Create modern namespace target for libarchive
if(TARGET archive_static AND NOT TARGET LibArchive::archive_static)
    add_library(LibArchive::archive_static ALIAS archive_static)
endif()

# Ensure libarchive is built after zlib
if (TARGET archive_static AND TARGET ZLIB::ZLIB)
    add_dependencies(archive_static ZLIB::ZLIB)
endif()

unset(POSIX_REGEX_LIB)
unset(ENABLE_WERROR)
unset(ENABLE_INSTALL)
unset(ENABLE_TEST)
unset(ENABLE_CNG)
unset(ENABLE_MBEDTLS)
unset(ENABLE_NETTLE)
unset(ENABLE_OPENSSL)
unset(ENABLE_ZLIB)
unset(ENABLE_BZip2)
unset(ENABLE_LZ4)
unset(ENABLE_LZO)
unset(ENABLE_LIBB2)
unset(ENABLE_LIBXML2)
unset(ENABLE_EXPAT)
unset(ENABLE_PCREPOSIX)
unset(ENABLE_PCRE2POSIX)
unset(ENABLE_LIBGCC)
unset(ENABLE_TAR)
unset(ENABLE_CPIO)
unset(ENABLE_CAT)
unset(ARCHIVE_BUILD_SHARED_LIBS)
unset(ENABLE_ZSTD)
unset(ENABLE_LZMA)
# Set LibArchive variables for compatibility
set(LibArchive_FOUND true CACHE BOOL "LibArchive library found")
# Note: Using modern namespace target LibArchive::archive_static instead of LibArchive_LIBRARIES variable
set(LibArchive_INCLUDE_DIR ${libarchive_SOURCE_DIR}/libarchive CACHE PATH "LibArchive include directory")
set(LibArchive_INCLUDE_DIRS ${libarchive_SOURCE_DIR}/libarchive CACHE PATH "LibArchive include directories")

# Bundled libcurl
set(CURL_VERSION "8.14.1")
string(REPLACE "." "_" CURL_TAG ${CURL_VERSION})
FetchContent_Declare(curl
    GIT_REPOSITORY https://github.com/curl/curl.git
    GIT_TAG curl-${CURL_TAG}
    ${USE_OVERRIDE_FIND_PACKAGE}
)
set(BUILD_CURL_EXE OFF CACHE BOOL "" FORCE)
set(BUILD_LIBCURL_DOCS OFF CACHE BOOL "" FORCE)
set(BUILD_MISC_DOCS OFF CACHE BOOL "" FORCE)
set(ENABLE_CURL_MANUAL OFF CACHE BOOL "" FORCE)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(CURL_USE_LIBPSL OFF CACHE BOOL "" FORCE)
set(CURL_USE_LIBSSH2 OFF CACHE BOOL "" FORCE)
set(CURL_DISABLE_ALTSVC ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_BASIC_AUTH ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_BEARER_AUTH ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_DIGEST_AUTH ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_KERBEROS_AUTH ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_NEGOTIATE_AUTH ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_NTLM ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_AWS ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_DICT ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_FILE ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_FTP ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_GOPHER ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_IMAP ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_LDAP ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_LDAPS ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_MQTT ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_POP3 ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_RTSP ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_SMB ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_SMTP ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_TELNET ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_TFTP ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_DOH ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_HSTS ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_IPFS ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_WEBSOCKETS ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_PROXY ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_QUIC ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_FORM_API ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_MIME ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_BINDLOCAL ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_GETOPTIONS ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_HEADERS_API ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_LIBCURL_OPTION ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_NETRC ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_PARSEDATE ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_SHA512_256 ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_SHUFFLE_DNS ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_SOCKETPAIR ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_SRP ON CACHE BOOL "" FORCE)
set(CURL_DISABLE_VERBOSE_STRINGS ON CACHE BOOL "" FORCE)
set(CURL_ENABLE_EXPORT_TARGET OFF CACHE BOOL "" FORCE)
set(CURL_DISABLE_INSTALL ON)
if (WIN32)
    set(CURL_USE_SCHANNEL ON CACHE BOOL "" FORCE)
    set(CURL_USE_GNUTLS OFF CACHE BOOL "" FORCE)
    set(CURL_DEFAULT_SSL_BACKEND "schannel")
    # Disable features that might pull in additional DLL dependencies
    set(CURL_USE_LIBPSL OFF CACHE BOOL "" FORCE)
    set(CURL_USE_LIBIDN2 OFF CACHE BOOL "" FORCE)
elseif (APPLE)
    # Use OpenSSL on macOS since it's available via Homebrew and widely supported
    set(CURL_USE_OPENSSL ON CACHE BOOL "" FORCE)
    set(CURL_USE_GNUTLS OFF CACHE BOOL "" FORCE)
    set(CURL_USE_MBEDTLS OFF CACHE BOOL "" FORCE)
    set(CURL_USE_WOLFSSL OFF CACHE BOOL "" FORCE)
    set(CURL_USE_BEARSSL OFF CACHE BOOL "" FORCE)
    set(CURL_USE_RUSTLS OFF CACHE BOOL "" FORCE)
    set(CURL_DEFAULT_SSL_BACKEND "openssl")
    set(CURL_USE_LIBPSL OFF CACHE BOOL "" FORCE)
    set(CURL_USE_LIBIDN2 OFF CACHE BOOL "" FORCE)
    # Use system zlib on macOS to avoid target conflicts
    set(CURL_ZLIB OFF CACHE BOOL "" FORCE)
else()
    set(CURL_USE_GNUTLS ON CACHE BOOL "" FORCE)
    set(CURL_DEFAULT_SSL_BACKEND "gnutls")
endif()

FetchContent_MakeAvailable(curl)

# Create modern namespace target for curl
if(TARGET libcurl_static AND NOT TARGET CURL::libcurl_static)
    add_library(CURL::libcurl_static ALIAS libcurl_static)
endif()

# Cleanup curl variables
unset(BUILD_CURL_EXE)
unset(BUILD_LIBCURL_DOCS)
unset(BUILD_MISC_DOCS)
unset(ENABLE_CURL_MANUAL)
unset(BUILD_EXAMPLES)
unset(CURL_USE_LIBPSL)
unset(CURL_USE_LIBSSH2)
unset(CURL_DISABLE_ALTSVC)
unset(CURL_DISABLE_BASIC_AUTH)
unset(CURL_DISABLE_BEARER_AUTH)
unset(CURL_DISABLE_DIGEST_AUTH)
unset(CURL_DISABLE_KERBEROS_AUTH)
unset(CURL_DISABLE_NEGOTIATE_AUTH)
unset(CURL_DISABLE_NTLM)
unset(CURL_DISABLE_AWS)
unset(CURL_DISABLE_DICT)
unset(CURL_DISABLE_FILE)
unset(CURL_DISABLE_FTP)
unset(CURL_DISABLE_GOPHER)
unset(CURL_DISABLE_IMAP)
unset(CURL_DISABLE_LDAP)
unset(CURL_DISABLE_LDAPS)
unset(CURL_DISABLE_MQTT)
unset(CURL_DISABLE_POP3)
unset(CURL_DISABLE_RTSP)
unset(CURL_DISABLE_SMB)
unset(CURL_DISABLE_SMTP)
unset(CURL_DISABLE_TELNET)
unset(CURL_DISABLE_TFTP)
unset(CURL_DISABLE_DOH)
unset(CURL_DISABLE_HSTS)
unset(CURL_DISABLE_IPFS)
unset(CURL_DISABLE_WEBSOCKETS)
unset(CURL_DISABLE_PROXY)
unset(CURL_DISABLE_QUIC)
unset(CURL_DISABLE_FORM_API)
unset(CURL_DISABLE_MIME)
unset(CURL_DISABLE_BINDLOCAL)
unset(CURL_DISABLE_GETOPTIONS)
unset(CURL_DISABLE_HEADERS_API)
unset(CURL_DISABLE_LIBCURL_OPTION)
unset(CURL_DISABLE_NETRC)
unset(CURL_DISABLE_PARSEDATE)
unset(CURL_DISABLE_SHA512_256)
unset(CURL_DISABLE_SHUFFLE_DNS)
unset(CURL_DISABLE_SOCKETPAIR)
unset(CURL_DISABLE_SRP)
unset(CURL_DISABLE_VERBOSE_STRINGS)
unset(CURL_ENABLE_EXPORT_TARGET)
unset(CURL_DISABLE_INSTALL)
unset(CURL_USE_SCHANNEL)
unset(CURL_DEFAULT_SSL_BACKEND)
unset(CURL_USE_GNUTLS)

# Set CURL variables for compatibility
set(CURL_FOUND true CACHE BOOL "CURL library found")
# Note: Using modern namespace target CURL::libcurl_static instead of CURL_LIBRARIES variable
set(CURL_INCLUDE_DIR ${curl_SOURCE_DIR}/include CACHE PATH "CURL include directory")
set(CURL_INCLUDE_DIRS ${curl_SOURCE_DIR}/include CACHE PATH "CURL include directories")

# Adding headers explicity so they are displayed in Qt Creator
set(HEADERS config.h imagewriter.h networkaccessmanagerfactory.h nan.h drivelistitem.h drivelistmodel.h drivelistmodelpollthread.h driveformatthread.h powersaveblocker.h cli.h
    downloadthread.h downloadextractthread.h localfileextractthread.h downloadstatstelemetry.h dependencies/mountutils/src/mountutils.hpp dependencies/sha256crypt/sha256crypt.h)

# Add dependencies
if (APPLE)
    set_source_files_properties("icons/openhdimagewriter.icns" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    set(PLATFORM_SOURCES
        acceleratedcryptographichash.cpp
        mac/macfile.cpp
        mac/macfile.h
        dependencies/mountutils/src/darwin/functions.cpp
        dependencies/drivelist/src/darwin/list.mm
        dependencies/drivelist/src/darwin/REDiskList.m
    )
    set(DEPENDENCIES icons/openhdimagewriter.icns)
    enable_language(OBJC C)
elseif (UNIX)
    find_package(GnuTLS REQUIRED)
    set(PLATFORM_SOURCES
        dependencies/mountutils/src/linux/functions.cpp
        linux/linuxdrivelist.cpp
        acceleratedcryptographichash_gnutls.cpp
    )
    set(EXTRALIBS ${EXTRALIBS} GnuTLS::GnuTLS)
    set(DEPENDENCIES "")
    # Platform definitions will be added after target creation
elseif (WIN32)
    set(PLATFORM_SOURCES
        acceleratedcryptographichash.cpp
        dependencies/mountutils/src/windows/functions.cpp
        dependencies/drivelist/src/windows/list.cpp
        windows/winfile.cpp
        windows/winfile.h
    )
    set(DEPENDENCIES
        windows/openhdimagewriter.rc
    )
    set(EXTRALIBS setupapi wlanapi)
    # Platform definitions will be added after target creation
endif()

# Include directories handled via target properties

# Test if we need libatomic
include(CheckCXXSourceCompiles)
check_cxx_source_compiles("
    #include <atomic>
    #include <stdint.h>
    int main() {
        std::atomic<int64_t> x;
        x = 1;
        return (int) x;
    }"
    atomicbuiltin)

if (NOT atomicbuiltin)
        find_library(ATOMIC_LIBRARY NAMES atomic libatomic.so.1)
        if (NOT ATOMIC_LIBRARY)
                message( FATAL_ERROR "Missing libatomic while architecture does need it" )
        endif()
endif()

# Include directories handled via target properties

# Test if we need libatomic
include(CheckCXXSourceCompiles)
check_cxx_source_compiles("
    #include <atomic>
    #include <stdint.h>
    int main() {
        std::atomic<int64_t> x;
        x = 1;
        return (int) x;
    }"
    atomicbuiltin)

if (NOT atomicbuiltin)
        find_library(ATOMIC_LIBRARY NAMES atomic libatomic.so.1)
        if (NOT ATOMIC_LIBRARY)
                message( FATAL_ERROR "Missing libatomic while architecture does need it" )
        endif()
endif()

include(TestBigEndian)
test_big_endian(IS_BIG_ENDIAN)
if( IS_BIG_ENDIAN )
    message( FATAL_ERROR "We currently only support 'little endian' CPU architectures" )
endif( IS_BIG_ENDIAN )

set(SOURCES ${PLATFORM_SOURCES} "main.cpp" "networkaccessmanagerfactory.cpp"
    "drivelistitem.cpp" "drivelistmodel.cpp" "drivelistmodelpollthread.cpp" "downloadthread.cpp" "downloadextractthread.cpp"
     "driveformatthread.cpp" "localfileextractthread.cpp" "powersaveblocker.cpp" "downloadstatstelemetry.cpp" "qml.qrc" "dependencies/sha256crypt/sha256crypt.c" "cli.cpp")

find_package(Qt6 6.5 QUIET COMPONENTS Core Quick LinguistTools Svg OPTIONAL_COMPONENTS Widgets DBus)
if (Qt6_FOUND)
    set(QT Qt6)
else()
    message(FATAL_ERROR "Missing suitable Qt library (must be at least version 6.5)" )
endif()

if (${QT}Widgets_FOUND)
    set(EXTRALIBS ${EXTRALIBS} ${QT}::Widgets)
endif()
if(${QT}DBus_FOUND AND UNIX AND NOT APPLE)
    set(DEPENDENCIES ${DEPENDENCIES} linux/udisks2api.cpp linux/udisks2api.h)
    set(EXTRALIBS ${EXTRALIBS} ${QT}::DBus)
    message("udisks2 support enabled")
endif()

# Find all translation files automatically
file(GLOB TRANSLATIONS CONFIGURE_DEPENDS "i18n/*.ts")
# Add translations using stable Qt6 pattern (matches rpi-imager reference)
qt_add_translation(QM_FILES ${TRANSLATIONS})
configure_file(i18n/translations.qrc "${CMAKE_CURRENT_BINARY_DIR}" COPYONLY)
set(SOURCES ${SOURCES} ${CMAKE_CURRENT_BINARY_DIR}/translations.qrc ${QM_FILES})

if (WIN32)
    # Adding WIN32 prevents a console window being opened on Windows
    add_executable(${PROJECT_NAME} WIN32 ${SOURCES} ${HEADERS} ${DEPENDENCIES})
else()
    add_executable(${PROJECT_NAME} ${SOURCES} ${HEADERS} ${DEPENDENCIES})
endif()

set_property(TARGET ${PROJECT_NAME} PROPERTY AUTOMOC ON)
set_property(TARGET ${PROJECT_NAME} PROPERTY AUTORCC ON)
set_property(TARGET ${PROJECT_NAME} PROPERTY AUTOUIC ON)

# Target-based compile definitions (modern CMake best practice)
target_compile_definitions(${PROJECT_NAME} PRIVATE
    IMAGER_VERSION_STR="${IMAGER_VERSION_STR}"
    IMAGER_VERSION_CSV=${IMAGER_VERSION_CSV}
    $<$<BOOL:${ENABLE_TELEMETRY}>:TELEMETRY_ENABLED_DEFAULT=true>
    $<$<NOT:$<BOOL:${ENABLE_TELEMETRY}>>:TELEMETRY_ENABLED_DEFAULT=false>
    $<$<BOOL:${ENABLE_CHECK_VERSION}>:CHECK_VERSION_DEFAULT=true>
    $<$<NOT:$<BOOL:${ENABLE_CHECK_VERSION}>>:CHECK_VERSION_DEFAULT=false>
)

# Platform-specific definitions
if(UNIX AND NOT APPLE)
    target_compile_definitions(${PROJECT_NAME} PRIVATE HAVE_GNUTLS)
elseif(WIN32)
    target_compile_definitions(${PROJECT_NAME} PRIVATE 
        HAVE_WINCRYPT
        _CRT_SECURE_NO_WARNINGS
        WINVER=0x0A00
        _WIN32_WINNT=0x0A00
        NTDDI_VERSION=0x0A000000
    )
endif()

# Target-based include directories (modern CMake best practice)
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CURL_INCLUDE_DIR}
    ${LibArchive_INCLUDE_DIR}
    ${LIBLZMA_INCLUDE_DIRS}
    ${ZLIB_INCLUDE_DIRS}
    ${ZSTD_INCLUDE_DIR}
)

# Create lupdate target (after executable target is created)
qt_add_lupdate(${PROJECT_NAME}
    TS_FILES ${TRANSLATIONS}
    OPTIONS -no-obsolete -locations none
)

# # Enable link time optimization if available
# include(CheckIPOSupported)
# check_ipo_supported(RESULT iposupported OUTPUT ipoerror)

# if(iposupported)
#     message("Enabled LTO")
#     set_property(TARGET ${PROJECT_NAME} PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
# else()
#     message(STATUS "LTO not supported: <${ipoerror}>")
# endif()

# Feature definitions will be added to target after creation

qt_policy(SET QTP0001 NEW)

if (QT_KNOWN_POLICY_QTP0004)
    qt_policy(SET QTP0004 NEW)
endif()

set(QT_QML_GENERATE_QMLLS_INI ON)

set(IMAGER_QML_FILES
    main.qml
    MsgPopup.qml
    OptionsPopup.qml
    UseSavedSettingsPopup.qml
    qmlcomponents/ImButton.qml
    qmlcomponents/ImCheckBox.qml
    qmlcomponents/ImRadioButton.qml
)

# C++ types exposed to QML
set(IMAGER_QML_CPP_TYPES
    imagewriter.cpp
)

qt_add_qml_module(${PROJECT_NAME}
    URI OpenHDImageWriter
    VERSION 1.0
    QML_FILES ${IMAGER_QML_FILES}
    SOURCES ${IMAGER_QML_CPP_TYPES}
    NO_CACHEGEN
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml_modules
    DEPENDENCIES QtQuick
    NO_PLUGIN
)

# Because dependencies are typically not available by default on Windows, build bundled code
if (WIN32)
    # Target Windows 10, in line with Qt6 requirements (definitions added to target)

    # Strip debug symbols
    add_custom_command(TARGET ${PROJECT_NAME}
        POST_BUILD
        COMMAND ${CMAKE_STRIP} "${CMAKE_BINARY_DIR}/${PROJECT_NAME}.exe")

    # Windeploy
    find_program(WINDEPLOYQT "windeployqt.exe" PATHS "${Qt6_ROOT}/bin")
    if (NOT WINDEPLOYQT)
        message(FATAL_ERROR "Unable to locate windeployqt.exe")
    endif()

    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/deploy")

    # Deployment is handled by GitHub Actions workflow
    # Just ensure windeployqt is available for CI
    message(STATUS "Windows deployment will be handled by CI workflow")
    
    # Configure NSIS installer script from template
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/windows/openhdimagewriter.nsi.in"
        "${CMAKE_BINARY_DIR}/openhdimagewriter.nsi"
        @ONLY
    )

    # Remove excess files
    add_custom_command(TARGET ${PROJECT_NAME}
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E remove
            "${CMAKE_BINARY_DIR}/deploy/imageformats/qtiff.dll"
            "${CMAKE_BINARY_DIR}/deploy/imageformats/qwebp.dll"
            "${CMAKE_BINARY_DIR}/deploy/imageformats/qgif.dll")

elseif(APPLE)
    find_library(Cocoa Cocoa)
    find_library(CoreFoundation CoreFoundation)
    find_library(DiskArbitration DiskArbitration)
    find_library(Security Security)
    find_library(IOKit IOKit)
    find_library(SystemConfiguration SystemConfiguration)
    set(EXTRALIBS ${EXTRALIBS} ${CoreFoundation} ${DiskArbitration} ${Security} ${Cocoa} ${IOKit} ${SystemConfiguration} iconv)
    
    # Configure Info.plist from template
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/mac/Info.plist.in"
        "${CMAKE_BINARY_DIR}/Info.plist"
        @ONLY
    )
    
    set_target_properties(${PROJECT_NAME} PROPERTIES 
        MACOSX_BUNDLE YES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_BINARY_DIR}/Info.plist"
    )

    find_program(MACDEPLOYQT "macdeployqt" PATHS "${Qt6_ROOT}/bin")
    if (NOT MACDEPLOYQT)
        message(FATAL_ERROR "Unable to locate macdeployqt")
    endif()

    add_custom_command(TARGET ${PROJECT_NAME}
        POST_BUILD
        COMMAND "${MACDEPLOYQT}" "${CMAKE_BINARY_DIR}/${PROJECT_NAME}.app" 
            -qmldir="${CMAKE_CURRENT_SOURCE_DIR}"
            -verbose=2
        COMMAND ${CMAKE_COMMAND} -E echo "Removing problematic SQL drivers to avoid missing dylib errors"
        COMMAND ${CMAKE_COMMAND} -E rm -f 
            "${CMAKE_BINARY_DIR}/${PROJECT_NAME}.app/Contents/PlugIns/sqldrivers/libqsqlodbc.dylib"
            "${CMAKE_BINARY_DIR}/${PROJECT_NAME}.app/Contents/PlugIns/sqldrivers/libqsqlpsql.dylib"
        COMMENT "Deploying Qt libraries and cleaning up problematic SQL plugins"
    )

else()
    # UNIX, Linux systems
    if (NOT CMAKE_CROSSCOMPILING)
        find_program(LSBLK "lsblk")
        if (NOT LSBLK)
            message(FATAL_ERROR "Unable to locate lsblk (used for disk enumeration)")
        endif()

        execute_process(COMMAND "${LSBLK}" "--json" OUTPUT_QUIET RESULT_VARIABLE ret)
        if (ret EQUAL "1")
            message(FATAL_ERROR "util-linux package too old. lsblk does not support --json (used for disk enumeration)")
        endif()
    endif()

    install(TARGETS ${PROJECT_NAME} DESTINATION bin)
    install(FILES icons/openhdimagewriter.png DESTINATION share/icons/hicolor/128x128/apps)
    install(FILES linux/openhdimagewriter.desktop DESTINATION share/applications)
    
    # Desktop file for AppImage
    install(FILES icons/openhdimagewriter.png DESTINATION share/pixmaps)
endif()

# Add dependency on ZLIB only if we're using bundled zlib
if(TARGET ZLIB::ZLIB)
    add_dependencies(${PROJECT_NAME} ZLIB::ZLIB)
endif()
# Include directories will be set via target properties

# Set up ZLIB library variable for linking
if(TARGET ZLIB::ZLIB)
    set(ZLIB_LINK_TARGET ZLIB::ZLIB)
else()
    # Fallback to system zlib (should not happen with our configuration above)
    find_package(ZLIB REQUIRED)
    set(ZLIB_LINK_TARGET ${ZLIB_LIBRARIES})
endif()

# Target-based include directories (modern CMake best practice)
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CURL_INCLUDE_DIR}
    ${LibArchive_INCLUDE_DIR}
    ${LIBLZMA_INCLUDE_DIRS}
    ${ZLIB_INCLUDE_DIRS}
    ${ZSTD_INCLUDE_DIR}
)

if(WIN32)
    # Maximum static linking for MinGW to minimize external dependencies
    if(CMAKE_COMPILER_IS_GNUCXX)
        set_target_properties(${PROJECT_NAME} PROPERTIES
            LINK_FLAGS "-static-libgcc -static-libstdc++ -Wl,-Bstatic,--whole-archive -lwinpthread -Wl,--no-whole-archive,-Bdynamic"
        )
        # Prefer static libraries on Windows
        set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".lib" ".dll.a")
    endif()
    target_link_libraries(${PROJECT_NAME} PRIVATE 
        ${QT}::Core ${QT}::Quick ${QT}::Svg 
        CURL::libcurl_static 
        LibArchive::archive_static 
        zstd::libzstd_static 
        liblzma 
        ${ZLIB_LINK_TARGET} 
        ${ATOMIC_LIBRARY} 
        ${EXTRALIBS} 
        crypt32 secur32 bcrypt
    )
else()
    # On macOS/Linux, let CMake handle transitive dependencies more cleanly
    if(APPLE)
        # Use target-based linking for better dependency management on macOS
        target_link_libraries(${PROJECT_NAME} PRIVATE 
            ${QT}::Core ${QT}::Quick ${QT}::Svg 
            CURL::libcurl_static 
            LibArchive::archive_static 
            zstd::libzstd_static 
            liblzma 
            ${ZLIB_LINK_TARGET} 
            ${ATOMIC_LIBRARY} 
            ${EXTRALIBS}
        )
    else()
        # Use consistent target-based linking for Linux too
        target_link_libraries(${PROJECT_NAME} PRIVATE 
            ${QT}::Core ${QT}::Quick ${QT}::Svg 
            CURL::libcurl_static 
            LibArchive::archive_static 
            zstd::libzstd_static 
            liblzma 
            ${ZLIB_LINK_TARGET} 
            ${ATOMIC_LIBRARY} 
            ${EXTRALIBS}
        )
    endif()
endif()