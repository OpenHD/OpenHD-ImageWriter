# SPDX-License-Identifier: Apache-2.0
# Download the pinned official NXP UUU Windows release and its redistribution
# license. EXPECTED_HASH makes a changed or corrupted upstream asset fail the
# build instead of entering an ImageWriter package.

if(NOT DEFINED OUTPUT_DIRECTORY)
    message(FATAL_ERROR "OUTPUT_DIRECTORY is required")
endif()

file(MAKE_DIRECTORY "${OUTPUT_DIRECTORY}")

set(UUU_VERSION "1.5.243")
set(UUU_URL "https://github.com/nxp-imx/mfgtools/releases/download/uuu_${UUU_VERSION}/uuu.exe")
set(UUU_SHA256 "f6b76a6246befabeadfebdc1cbfe58f35939596caf7b78717ceab599b0c85027")
set(UUU_LICENSE_URL "https://raw.githubusercontent.com/nxp-imx/mfgtools/uuu_${UUU_VERSION}/LICENSE")
set(UUU_LICENSE_SHA256 "cc8d47f7b9260f6669ecd41c24554c552f17581d81ee8fc602c6d23edb8bf495")

file(DOWNLOAD "${UUU_URL}" "${OUTPUT_DIRECTORY}/uuu.exe"
     EXPECTED_HASH "SHA256=${UUU_SHA256}"
     TLS_VERIFY ON
     STATUS UUU_DOWNLOAD_STATUS)
list(GET UUU_DOWNLOAD_STATUS 0 UUU_DOWNLOAD_CODE)
list(GET UUU_DOWNLOAD_STATUS 1 UUU_DOWNLOAD_MESSAGE)
if(NOT UUU_DOWNLOAD_CODE EQUAL 0)
    message(FATAL_ERROR "Failed to download NXP UUU ${UUU_VERSION}: ${UUU_DOWNLOAD_MESSAGE}")
endif()

file(DOWNLOAD "${UUU_LICENSE_URL}" "${OUTPUT_DIRECTORY}/uuu-LICENSE.txt"
     EXPECTED_HASH "SHA256=${UUU_LICENSE_SHA256}"
     TLS_VERIFY ON
     STATUS UUU_LICENSE_STATUS)
list(GET UUU_LICENSE_STATUS 0 UUU_LICENSE_CODE)
list(GET UUU_LICENSE_STATUS 1 UUU_LICENSE_MESSAGE)
if(NOT UUU_LICENSE_CODE EQUAL 0)
    message(FATAL_ERROR "Failed to download the NXP UUU license: ${UUU_LICENSE_MESSAGE}")
endif()

message(STATUS "Bundled NXP UUU ${UUU_VERSION}")
