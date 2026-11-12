cmake_minimum_required(VERSION 3.9.4)

execute_process(COMMAND "${NODE}" -p "require('node:sqlite') && process.version"
    OUTPUT_VARIABLE node_version OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE status)
if(NOT status EQUAL 0)
    message(FATAL_ERROR "The offline map renderer requires Node.js with built-in SQLite (22.13 or later).")
endif()

file(MAKE_DIRECTORY "${BUNDLE}/assets/fonts" "${BUNDLE}/assets/sprites")
file(COPY "${SOURCE}/render.mjs" "${SOURCE}/package.json" "${SOURCE}/package-lock.json" DESTINATION "${BUNDLE}")
execute_process(COMMAND "${NPM}" ci --omit=dev --no-audit --no-fund WORKING_DIRECTORY "${BUNDLE}"
    RESULT_VARIABLE status)
if(NOT status EQUAL 0)
    message(FATAL_ERROR "Could not install the offline map renderer dependencies.")
endif()

function(download url path)
    file(DOWNLOAD "${url}" "${path}" TLS_VERIFY ON STATUS result ${ARGN})
    list(GET result 0 code)
    if(NOT code EQUAL 0)
        list(GET result 1 error)
        message(FATAL_ERROR "Could not download an offline map asset: ${error}")
    endif()
endfunction()

function(install_archive url hash directory)
    set(archive "${BUNDLE}/map-assets.tar.gz")
    download("${url}" "${archive}" EXPECTED_HASH "SHA256=${hash}")
    execute_process(COMMAND "${TAR}" -xf "${archive}" -C "${directory}" RESULT_VARIABLE status)
    if(NOT status EQUAL 0)
        message(FATAL_ERROR "Could not extract the offline map assets.")
    endif()
    file(REMOVE "${archive}")
endfunction()

install_archive("https://github.com/versatiles-org/versatiles-fonts/releases/download/v3.0.0/noto_sans.tar.gz"
    "f58be6be2eb3d127b6ff1c90d828b69ff4807d1d88cd13a43930943fda0e334e" "${BUNDLE}/assets/fonts")
install_archive("https://github.com/versatiles-org/versatiles-style/releases/download/v9.1.0/sprites.tar.gz"
    "213786415c738338e0c95744af81d363893456e45471b06d2c8907e32be52903" "${BUNDLE}/assets/sprites")
download("https://raw.githubusercontent.com/nodejs/node/${node_version}/LICENSE" "${BUNDLE}/Node-LICENSE.txt")
download("https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/OFL.txt" "${BUNDLE}/NotoSans-OFL.txt")
download("https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/LICENSE" "${BUNDLE}/NotoSansCJK-OFL.txt")
file(WRITE "${BUNDLE}/VersaTiles-NOTICE.txt" "VersaTiles style (MIT) and sprites (CC0 1.0)\nhttps://github.com/versatiles-org/versatiles-style\nNoto Sans glyphs prepared by VersaTiles Fonts\nhttps://github.com/versatiles-org/versatiles-fonts\n")
get_filename_component(node_path "${NODE}" REALPATH)
if(WIN32)
    set(node_name node.exe)
    # MapLibre's Windows addon is built with MSVC. Put the redistributable
    # runtime next to Node so the installer does not need a system-wide install.
    execute_process(COMMAND "${NODE}" -p "process.arch"
        OUTPUT_VARIABLE node_arch OUTPUT_STRIP_TRAILING_WHITESPACE)
    find_program(VSWHERE NAMES vswhere PATHS "$ENV{ProgramFiles\(x86\)}/Microsoft Visual Studio/Installer")
    if(VSWHERE)
        execute_process(COMMAND "${VSWHERE}" -latest -products "*" -property installationPath
            OUTPUT_VARIABLE visual_studio OUTPUT_STRIP_TRAILING_WHITESPACE)
        file(TO_CMAKE_PATH "${visual_studio}" visual_studio)
    endif()
    file(TO_CMAKE_PATH "$ENV{VCToolsRedistDir}" vc_redist)
    file(GLOB crt_directories LIST_DIRECTORIES true
        "${vc_redist}/${node_arch}/Microsoft.VC*.CRT"
        "${visual_studio}/VC/Redist/MSVC/*/${node_arch}/Microsoft.VC*.CRT")
    list(REVERSE crt_directories)
    find_file(crt_library NAMES msvcp140.dll PATHS ${crt_directories} NO_DEFAULT_PATH)
    if(NOT crt_library)
        message(FATAL_ERROR "Install the Visual Studio C++ Redistributable build component for ${node_arch}.")
    endif()
    get_filename_component(crt_directory "${crt_library}" DIRECTORY)
    foreach(library msvcp140.dll msvcp140_codecvt_ids.dll vcruntime140.dll vcruntime140_1.dll)
        configure_file("${crt_directory}/${library}" "${BUNDLE}/${library}" COPYONLY)
    endforeach()
else()
    set(node_name node)
endif()
configure_file("${node_path}" "${BUNDLE}/${node_name}" COPYONLY)
if(DEPLOY)
    file(COPY "${BUNDLE}/" DESTINATION "${DEPLOY}" PATTERN ".prepared" EXCLUDE)
endif()
file(WRITE "${BUNDLE}/.prepared" "")
