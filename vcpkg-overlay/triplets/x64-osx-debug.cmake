set(VCPKG_TARGET_ARCHITECTURE x64)




set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES x86_64)

# Toolchain setup
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/../scripts/toolchains/osx.cmake")

# Port specialization
include("${CMAKE_CURRENT_LIST_DIR}/osx/port.cmake")