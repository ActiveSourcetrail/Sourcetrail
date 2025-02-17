set(LLVM_VERSION "11.0.0")

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

set(PATCHES
    0001-add-msvc-options.patch     # Fixed in LLVM 12.0.0
    0002-fix-install-paths.patch    # This patch fixes paths in ClangConfig.cmake, LLVMConfig.cmake, LLDConfig.cmake etc.
    0003-fix-openmp-debug.patch
    0004-fix-dr-1734.patch
    0005-fix-tools-path.patch
    0006-workaround-msvc-bug.patch  # Fixed in LLVM 12.0.0
)

if(NOT "devel" IN_LIST FEATURES)
    list(APPEND PATCHES
        0007-build-only-sourcetrail-required.patch # For Sourcetrail project
    )
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO llvm/llvm-project
    REF llvmorg-${LLVM_VERSION}
    SHA512 b6d38871ccce0e086e27d35e42887618d68e57d8274735c59e3eabc42dee352412489296293f8d5169fe0044936345915ee7da61ebdc64ec10f7737f6ecd90f2
    HEAD_REF master
    PATCHES ${PATCHES}
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
    tools LLVM_BUILD_TOOLS
    tools LLVM_INCLUDE_TOOLS
    utils LLVM_BUILD_UTILS
    utils LLVM_INCLUDE_UTILS
    enable-rtti LLVM_ENABLE_RTTI
    enable-ffi LLVM_ENABLE_FFI
    enable-terminfo LLVM_ENABLE_TERMINFO
    enable-threads LLVM_ENABLE_THREADS
    enable-eh LLVM_ENABLE_EH
    enable-bindings LLVM_ENABLE_BINDINGS
)

# LLVM generates CMake error due to Visual Studio version 16.4 is known to miscompile part of LLVM.
# LLVM_TEMPORARILY_ALLOW_OLD_TOOLCHAIN=ON disables this error.
# See https://developercommunity.visualstudio.com/content/problem/845933/miscompile-boolean-condition-deduced-to-be-always.html
# and thread "[llvm-dev] Longstanding failing tests - clang-tidy, MachO, Polly" on llvm-dev Jan 21-23 2020.
list(APPEND FEATURE_OPTIONS
    -DLLVM_TEMPORARILY_ALLOW_OLD_TOOLCHAIN=ON
)

# By default assertions are enabled for Debug configuration only.
if("enable-assertions" IN_LIST FEATURES)
    # Force enable assertions for all configurations.
    list(APPEND FEATURE_OPTIONS
        -DLLVM_ENABLE_ASSERTIONS=ON
    )
elseif("disable-assertions" IN_LIST FEATURES)
    # Force disable assertions for all configurations.
    list(APPEND FEATURE_OPTIONS
        -DLLVM_ENABLE_ASSERTIONS=OFF
    )
endif()

# LLVM_ABI_BREAKING_CHECKS can be WITH_ASSERTS (default), FORCE_ON or FORCE_OFF.
# By default abi-breaking checks are enabled if assertions are enabled.
if("enable-abi-breaking-checks" IN_LIST FEATURES)
    # Force enable abi-breaking checks.
    list(APPEND FEATURE_OPTIONS
        -DLLVM_ABI_BREAKING_CHECKS=FORCE_ON
    )
elseif("disable-abi-breaking-checks" IN_LIST FEATURES)
    # Force disable abi-breaking checks.
    list(APPEND FEATURE_OPTIONS
        -DLLVM_ABI_BREAKING_CHECKS=FORCE_OFF
    )
endif()

set(LLVM_ENABLE_PROJECTS)
if("clang" IN_LIST FEATURES OR "clang-tools-extra" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "clang")
    if(NOT "tools" IN_LIST FEATURES)
        list(REMOVE_ITEM FEATURE_OPTIONS 
            -DLLVM_BUILD_TOOLS=OFF
            -DLLVM_INCLUDE_TOOLS=OFF
        )
        list(APPEND FEATURE_OPTIONS
            -DLLVM_BUILD_TOOLS=ON
            -DLLVM_INCLUDE_TOOLS=ON
        )
    endif()

    if("disable-clang-static-analyzer" IN_LIST FEATURES)
        list(APPEND FEATURE_OPTIONS
            # Disable ARCMT
            -DCLANG_ENABLE_ARCMT=OFF
            # Disable static analyzer
            -DCLANG_ENABLE_STATIC_ANALYZER=OFF
        )
    endif()
endif()
if("clang-tools-extra" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "clang-tools-extra")
endif()
if("compiler-rt" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "compiler-rt")
endif()
if("flang" IN_LIST FEATURES)
    # Disable Flang on Windows (see http://lists.llvm.org/pipermail/flang-dev/2020-July/000448.html).
    if(VCPKG_TARGET_IS_WINDOWS)
        message(FATAL_ERROR "Building Flang with MSVC is not supported.")
    endif()
    list(APPEND LLVM_ENABLE_PROJECTS "flang")
    list(APPEND FEATURE_OPTIONS
        # Flang requires C++17
        -DCMAKE_CXX_STANDARD=17
    )
endif()
if("lld" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "lld")
endif()
if("lldb" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "lldb")
endif()
if("mlir" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "mlir")
endif()
if("openmp" IN_LIST FEATURES)
    # Disable OpenMP on Windows (see https://bugs.llvm.org/show_bug.cgi?id=45074).
    if(VCPKG_TARGET_IS_WINDOWS)
        message(FATAL_ERROR "Building OpenMP with MSVC is not supported.")
    endif()
    list(APPEND LLVM_ENABLE_PROJECTS "openmp")
    # Perl is required for the OpenMP run-time
    vcpkg_find_acquire_program(PERL)
    list(APPEND FEATURE_OPTIONS
        "-DPERL_EXECUTABLE=${PERL}"
    )
    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        list(APPEND FEATURE_OPTIONS
            -DLIBOMP_DEFAULT_LIB_NAME=libompd
        )
    endif()
endif()
if("polly" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "polly")
endif()

if("tools" IN_LIST FEATURES)
    list(APPEND FEATURE_OPTIONS -DCLANG_RESOURCE_DIR=../../lib/clang/11.0.0)
else()
    list(APPEND FEATURE_OPTIONS
        -DCLANG_TOOL_AMDGPU_ARCH_BUILD=OFF
        -DCLANG_TOOL_APINOTES_TEST_BUILD=OFF
        -DCLANG_TOOL_ARCMT_TEST_BUILD=OFF
        -DCLANG_TOOL_C_ARCMT_TEST_BUILD=OFF
        -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF
        -DCLANG_TOOL_CLANG_CHECK_BUILD=OFF
        -DCLANG_TOOL_CLANG_DIFF_BUILD=OFF
        -DCLANG_TOOL_CLANG_EXTDEF_MAPPING_BUILD=OFF
        -DCLANG_TOOL_CLANG_FORMAT_BUILD=OFF
        -DCLANG_TOOL_CLANG_FORMAT_VS_BUILD=OFF
        -DCLANG_TOOL_CLANG_FUZZER_BUILD=OFF
        -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF
        -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF
        -DCLANG_TOOL_CLANG_OFFLOAD_BUNDLER_BUILD=OFF
        -DCLANG_TOOL_CLANG_OFFLOAD_PACKAGER_BUILD=OFF
        -DCLANG_TOOL_CLANG_OFFLOAD_WRAPPER_BUILD=OFF
        -DCLANG_TOOL_CLANG_REFACTOR_BUILD=OFF
        -DCLANG_TOOL_CLANG_RENAME_BUILD=OFF
        -DCLANG_TOOL_CLANG_REPL_BUILD=OFF
        -DCLANG_TOOL_CLANG_SCAN_DEPS_BUILD=OFF
        -DCLANG_TOOL_CLANG_SHLIB_BUILD=OFF
        -DCLANG_TOOL_DIAGTOOL_BUILD=OFF
        -DCLANG_TOOL_DRIVER_BUILD=OFF
        -DCLANG_TOOL_LIBCLANG_BUILD=OFF
        -DCLANG_TOOL_NVPTX_ARCH_BUILD=OFF
        -DCLANG_TOOL_SCAN_BUILD_BUILD=OFF
        -DCLANG_TOOL_SCAN_BUILD_PY_BUILD=OFF
        -DCLANG_TOOL_SCAN_VIEW_BUILD=OFF
        -DCLANG_TOOLING_BUILD_AST_INTROSPECTION=OFF
        -DLLVM_TOOL_BOLT_BUILD=OFF
        -DLLVM_TOOL_BUGPOINT_BUILD=OFF
        -DLLVM_TOOL_BUGPOINT_PASSES_BUILD=OFF
        -DLLVM_TOOL_CLANG_BUILD=OFF
        -DLLVM_TOOL_CLANG_TOOLS_EXTRA_BUILD=OFF
        -DLLVM_TOOL_COMPILER_RT_BUILD=OFF
        -DLLVM_TOOL_CROSS_PROJECT_TESTS_BUILD=OFF
        -DLLVM_TOOL_DRAGONEGG_BUILD=OFF
        -DLLVM_TOOL_DSYMUTIL_BUILD=OFF
        -DLLVM_TOOL_DXIL_DIS_BUILD=OFF
        -DLLVM_TOOL_FLANG_BUILD=OFF
        -DLLVM_TOOL_GOLD_BUILD=OFF
        -DLLVM_TOOL_LIBC_BUILD=OFF
        -DLLVM_TOOL_LIBCLC_BUILD=OFF
        -DLLVM_TOOL_LLC_BUILD=OFF
        -DLLVM_TOOL_LLD_BUILD=OFF
        -DLLVM_TOOL_LLDB_BUILD=OFF
        -DLLVM_TOOL_LLI_BUILD=OFF
        -DLLVM_TOOL_LLVM_AR_BUILD=OFF
        -DLLVM_TOOL_LLVM_AS_BUILD=OFF
        -DLLVM_TOOL_LLVM_AS_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_BCANALYZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_C_TEST_BUILD=OFF
        -DLLVM_TOOL_LLVM_CAT_BUILD=OFF
        -DLLVM_TOOL_LLVM_CFI_VERIFY_BUILD=OFF
        -DLLVM_TOOL_LLVM_CONFIG_BUILD=OFF
        -DLLVM_TOOL_LLVM_COV_BUILD=OFF
        -DLLVM_TOOL_LLVM_CVTRES_BUILD=OFF
        -DLLVM_TOOL_LLVM_CXXDUMP_BUILD=OFF
        -DLLVM_TOOL_LLVM_CXXFILT_BUILD=OFF
        -DLLVM_TOOL_LLVM_CXXMAP_BUILD=OFF
        -DLLVM_TOOL_LLVM_DEBUGINFO_ANALYZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_DEBUGINFOD_BUILD=OFF
        -DLLVM_TOOL_LLVM_DEBUGINFOD_FIND_BUILD=OFF
        -DLLVM_TOOL_LLVM_DIFF_BUILD=OFF
        -DLLVM_TOOL_LLVM_DIS_BUILD=OFF
        -DLLVM_TOOL_LLVM_DIS_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_DLANG_DEMANGLE_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_DRIVER_BUILD=OFF
        -DLLVM_TOOL_LLVM_DWARFDUMP_BUILD=OFF
        -DLLVM_TOOL_LLVM_DWARFUTIL_BUILD=OFF
        -DLLVM_TOOL_LLVM_DWP_BUILD=OFF
        -DLLVM_TOOL_LLVM_ELFABI_BUILD=OFF
        -DLLVM_TOOL_LLVM_EXEGESIS_BUILD=OFF
        -DLLVM_TOOL_LLVM_EXTRACT_BUILD=OFF
        -DLLVM_TOOL_LLVM_GO_BUILD=OFF
        -DLLVM_TOOL_LLVM_GSYMUTIL_BUILD=OFF
        -DLLVM_TOOL_LLVM_IFS_BUILD=OFF
        -DLLVM_TOOL_LLVM_ISEL_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_ITANIUM_DEMANGLE_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_JITLINK_BUILD=OFF
        -DLLVM_TOOL_LLVM_JITLISTENER_BUILD=OFF
        -DLLVM_TOOL_LLVM_LIBTOOL_DARWIN_BUILD=OFF
        -DLLVM_TOOL_LLVM_LINK_BUILD=OFF
        -DLLVM_TOOL_LLVM_LIPO_BUILD=OFF
        -DLLVM_TOOL_LLVM_LTO_BUILD=OFF
        -DLLVM_TOOL_LLVM_LTO2_BUILD=OFF
        -DLLVM_TOOL_LLVM_MC_ASSEMBLE_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_MC_BUILD=OFF
        -DLLVM_TOOL_LLVM_MC_DISASSEMBLE_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_MCA_BUILD=OFF
        -DLLVM_TOOL_LLVM_MICROSOFT_DEMANGLE_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_ML_BUILD=OFF
        -DLLVM_TOOL_LLVM_MODEXTRACT_BUILD=OFF
        -DLLVM_TOOL_LLVM_MT_BUILD=OFF
        -DLLVM_TOOL_LLVM_NM_BUILD=OFF
        -DLLVM_TOOL_LLVM_OBJCOPY_BUILD=OFF
        -DLLVM_TOOL_LLVM_OBJDUMP_BUILD=OFF
        -DLLVM_TOOL_LLVM_OPT_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_OPT_REPORT_BUILD=OFF
        -DLLVM_TOOL_LLVM_PDBUTIL_BUILD=OFF
        -DLLVM_TOOL_LLVM_PROFDATA_BUILD=OFF
        -DLLVM_TOOL_LLVM_PROFGEN_BUILD=OFF
        -DLLVM_TOOL_LLVM_RC_BUILD=OFF
        -DLLVM_TOOL_LLVM_READOBJ_BUILD=OFF
        -DLLVM_TOOL_LLVM_REDUCE_BUILD=OFF
        -DLLVM_TOOL_LLVM_REMARK_SIZE_DIFF_BUILD=OFF
        -DLLVM_TOOL_LLVM_REMARKUTIL_BUILD=OFF
        -DLLVM_TOOL_LLVM_RTDYLD_BUILD=OFF
        -DLLVM_TOOL_LLVM_RUST_DEMANGLE_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_SHLIB_BUILD=OFF
        -DLLVM_TOOL_LLVM_SIM_BUILD=OFF
        -DLLVM_TOOL_LLVM_SIZE_BUILD=OFF
        -DLLVM_TOOL_LLVM_SPECIAL_CASE_LIST_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_SPLIT_BUILD=OFF
        -DLLVM_TOOL_LLVM_STRESS_BUILD=OFF
        -DLLVM_TOOL_LLVM_STRINGS_BUILD=OFF
        -DLLVM_TOOL_LLVM_SYMBOLIZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_TAPI_DIFF_BUILD=OFF
        -DLLVM_TOOL_LLVM_TLI_CHECKER_BUILD=OFF
        -DLLVM_TOOL_LLVM_UNDNAME_BUILD=OFF
        -DLLVM_TOOL_LLVM_XRAY_BUILD=OFF
        -DLLVM_TOOL_LLVM_YAML_NUMERIC_PARSER_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LLVM_YAML_PARSER_FUZZER_BUILD=OFF
        -DLLVM_TOOL_LTO_BUILD=OFF
        -DLLVM_TOOL_MLIR_BUILD=OFF
        -DLLVM_TOOL_OBJ2YAML_BUILD=OFF
        -DLLVM_TOOL_OPENMP_BUILD=OFF
        -DLLVM_TOOL_OPT_BUILD=OFF
        -DLLVM_TOOL_OPT_VIEWER_BUILD=OFF
        -DLLVM_TOOL_POLLY_BUILD=OFF
        -DLLVM_TOOL_PSTL_BUILD=OFF
        -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF
        -DLLVM_TOOL_SANCOV_BUILD=OFF
        -DLLVM_TOOL_SANSTATS_BUILD=OFF
        -DLLVM_TOOL_SPLIT_FILE_BUILD=OFF
        -DLLVM_TOOL_VERIFY_USELISTORDER_BUILD=OFF
        -DLLVM_TOOL_VFABI_DEMANGLE_FUZZER_BUILD=OFF
        -DLLVM_TOOL_XCODE_TOOLCHAIN_BUILD=OFF
        -DLLVM_TOOL_YAML2OBJ_BUILD=OFF
    )
endif()

set(known_llvm_targets
    AArch64
    AMDGPU
    ARM
    AVR
    BPF
    Hexagon
    Lanai
    Mips 
    MSP430
    NVPTX
    PowerPC
    RISCV
    Sparc
    SystemZ 
    WebAssembly
    X86
    XCore
)

set(LLVM_TARGETS_TO_BUILD "")
foreach(llvm_target IN LISTS known_llvm_targets)
    string(TOLOWER "target-${llvm_target}" feature_name)
    if(feature_name IN_LIST FEATURES)
        list(APPEND LLVM_TARGETS_TO_BUILD "${llvm_target}")
    endif()
endforeach()

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON3_DIR ${PYTHON3} DIRECTORY)
vcpkg_add_to_path(${PYTHON3_DIR})

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}/llvm
    PREFER_NINJA
    OPTIONS
        ${FEATURE_OPTIONS}
        -DLLVM_INCLUDE_BENCHMARKS=OFF
        -DLLVM_BUILD_BENCHMARKS=OFF
        -DLLVM_INCLUDE_DOCS=OFF
        -DLLVM_BUILD_DOCS=OFF
        -DLLVM_INCLUDE_EXAMPLES=OFF
        -DLLVM_BUILD_EXAMPLES=OFF
        -DLLVM_INCLUDE_TESTS=OFF
        -DLLVM_BUILD_TESTS=OFF
        -DLLVM_INCLUDE_RUNTIMES=OFF
        -DLLVM_BUILD_RUNTIME=OFF
        -DLLVM_BUILD_RUNTIMES=OFF
        -DLLVM_ENABLE_DIA_SDK=OFF
        -DLLVM_ENABLE_OCAMLDOC=OFF
        # Disable optional dependencies to libxml2 and zlib.
        -DLLVM_ENABLE_LIBXML2=OFF
        -DLLVM_ENABLE_ZLIB=OFF
        # Force TableGen to be built with optimization. This will significantly improve build time.
        -DLLVM_OPTIMIZED_TABLEGEN=ON
        "-DLLVM_ENABLE_PROJECTS=${LLVM_ENABLE_PROJECTS}"
        "-DLLVM_TARGETS_TO_BUILD=${LLVM_TARGETS_TO_BUILD}"
        -DPACKAGE_VERSION=${LLVM_VERSION}
        # Limit the maximum number of concurrent link jobs to 1. This should fix low amount of memory issue for link.
        -DLLVM_PARALLEL_LINK_JOBS=1
        # Disable build LLVM-C.dll (Windows only) due to doesn't compile with CMAKE_DEBUG_POSTFIX
        -DLLVM_BUILD_LLVM_C_DYLIB=OFF
        # Path for binary subdirectory (defaults to 'bin')
        -DLLVM_TOOLS_INSTALL_DIR=tools/llvm
    OPTIONS_DEBUG
        -DCMAKE_DEBUG_POSTFIX=d
)

vcpkg_install_cmake()

if("clang" IN_LIST FEATURES)
    vcpkg_fixup_cmake_targets(CONFIG_PATH "share/clang" TARGET_PATH "share/clang" DO_NOT_DELETE_PARENT_CONFIG_PATH)
    file(INSTALL ${SOURCE_PATH}/clang/LICENSE.TXT DESTINATION ${CURRENT_PACKAGES_DIR}/share/clang RENAME copyright)
endif()

if("clang-tools-extra" IN_LIST FEATURES)
    # Remove empty include directory include/clang-tidy/plugin
    file(GLOB_RECURSE INCLUDE_CLANG_TIDY_PLUGIN_FILES "${CURRENT_PACKAGES_DIR}/include/clang-tidy/plugin/*")
    if(NOT INCLUDE_CLANG_TIDY_PLUGIN_FILES)
        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/clang-tidy/plugin")
    endif()
endif()

if("flang" IN_LIST FEATURES)
    vcpkg_fixup_cmake_targets(CONFIG_PATH "share/flang" TARGET_PATH "share/flang" DO_NOT_DELETE_PARENT_CONFIG_PATH)
    file(INSTALL ${SOURCE_PATH}/flang/LICENSE.TXT DESTINATION ${CURRENT_PACKAGES_DIR}/share/flang RENAME copyright)
    # Remove empty include directory /include/flang/Config
    file(GLOB_RECURSE INCLUDE_FLANG_CONFIG_FILES "${CURRENT_PACKAGES_DIR}/include/flang/Config/*")
    if(NOT INCLUDE_FLANG_CONFIG_FILES)
        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/flang/Config")
    endif()
endif()

if("lld" IN_LIST FEATURES)
    vcpkg_fixup_cmake_targets(CONFIG_PATH "share/lld" TARGET_PATH "share/lld" DO_NOT_DELETE_PARENT_CONFIG_PATH)
    file(INSTALL ${SOURCE_PATH}/lld/LICENSE.TXT DESTINATION ${CURRENT_PACKAGES_DIR}/share/lld RENAME copyright)
endif()

if("mlir" IN_LIST FEATURES)
    vcpkg_fixup_cmake_targets(CONFIG_PATH "share/mlir" TARGET_PATH "share/mlir" DO_NOT_DELETE_PARENT_CONFIG_PATH)
    file(INSTALL ${SOURCE_PATH}/mlir/LICENSE.TXT DESTINATION ${CURRENT_PACKAGES_DIR}/share/mlir RENAME copyright)
endif()

if("polly" IN_LIST FEATURES)
    vcpkg_fixup_cmake_targets(CONFIG_PATH "share/polly" TARGET_PATH "share/polly" DO_NOT_DELETE_PARENT_CONFIG_PATH)
    file(INSTALL ${SOURCE_PATH}/polly/LICENSE.TXT DESTINATION ${CURRENT_PACKAGES_DIR}/share/polly RENAME copyright)
endif()

vcpkg_fixup_cmake_targets(CONFIG_PATH "share/llvm" TARGET_PATH "share/llvm")
file(INSTALL ${SOURCE_PATH}/llvm/LICENSE.TXT DESTINATION ${CURRENT_PACKAGES_DIR}/share/llvm RENAME copyright)

if(VCPKG_TARGET_IS_WINDOWS)
    set(LLVM_EXECUTABLE_REGEX [[^([^.]*|[^.]*\.lld)\.exe$]])
else()
    set(LLVM_EXECUTABLE_REGEX [[^([^.]*|[^.]*\.lld)$]])
endif()

file(GLOB LLVM_TOOL_FILES "${CURRENT_PACKAGES_DIR}/bin/*")
set(LLVM_TOOLS)
foreach(tool_file IN LISTS LLVM_TOOL_FILES)
    get_filename_component(tool_file "${tool_file}" NAME)
    if(tool_file MATCHES "${LLVM_EXECUTABLE_REGEX}")
        list(APPEND LLVM_TOOLS "${CMAKE_MATCH_1}")
    endif()
endforeach()

if(LLVM_TOOLS)
    vcpkg_copy_tools(TOOL_NAMES ${LLVM_TOOLS} AUTO_CLEAN)
endif()

if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/share)
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/tools)
endif()

# LLVM still generates a few DLLs in the static build:
# * libclang.dll
# * LTO.dll
# * Remarks.dll
set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
