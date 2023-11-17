set(VCPKG_TARGET_ARCHITECTURE x86)
set(VCPKG_PLATFORM_TOOLSET "v141")
set(VCPKG_DEP_INFO_OVERRIDE_VARS "v141")


# Toolchain setup
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/../scripts/toolchains/windows.cmake")

# Setting VCPKG_CHAINLOAD_TOOLCHAIN_FILE deactivates automatic vcvars setup so reenable it!
set(VCPKG_LOAD_VCVARS_ENV ON)

# Port specialization
include("${CMAKE_CURRENT_LIST_DIR}/windows/port.cmake")
