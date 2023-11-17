set(VCPKG_TARGET_ARCHITECTURE x64)




set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# Toolchain setup
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/../scripts/toolchains/linux.cmake")

# Port specialization
include("${CMAKE_CURRENT_LIST_DIR}/linux/port.cmake")