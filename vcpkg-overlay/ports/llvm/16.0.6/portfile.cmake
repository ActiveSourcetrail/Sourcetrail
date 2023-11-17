vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO llvm/llvm-project
    REF "llvmorg-${VERSION}"
    SHA512 6f084ac08cc5ec99996eb59fa7d5a8ea3b9ebc5b78159b87a868ebfd049b9f9a9048824df1a545e2a20bedff57ebe26f57e57cbc7bd9433edcd36424d973a4d5
    HEAD_REF main
    PATCHES
        0001-Fix-install-paths.patch    # This patch fixes paths in ClangConfig.cmake, LLVMConfig.cmake, LLDConfig.cmake etc.
        0003-Fix-tools-path.patch
        0005-Fix-tools-install-path.patch
        0007-Fix-install-bolt.patch
        0009-disable-libomp-aliases.patch
        0010-remove-numpy.patch
        0012-create-destination-mlir-directory.patch
)

vcpkg_check_features(
    OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools LLVM_BUILD_TOOLS
        tools LLVM_INCLUDE_TOOLS
        utils LLVM_BUILD_UTILS
        utils LLVM_INCLUDE_UTILS
        utils LLVM_INSTALL_UTILS
        enable-rtti LLVM_ENABLE_RTTI
        enable-ffi LLVM_ENABLE_FFI
        enable-terminfo LLVM_ENABLE_TERMINFO
        enable-threads LLVM_ENABLE_THREADS
        enable-ios COMPILER_RT_ENABLE_IOS
        enable-eh LLVM_ENABLE_EH
        enable-bindings LLVM_ENABLE_BINDINGS
)

vcpkg_cmake_get_vars(cmake_vars_file)
include("${cmake_vars_file}")

# LLVM generates CMake error due to Visual Studio version 16.4 is known to miscompile part of LLVM.
# LLVM_TEMPORARILY_ALLOW_OLD_TOOLCHAIN=ON disables this error.
# See https://developercommunity.visualstudio.com/content/problem/845933/miscompile-boolean-condition-deduced-to-be-always.html
# and thread "[llvm-dev] Longstanding failing tests - clang-tidy, MachO, Polly" on llvm-dev Jan 21-23 2020.
if(VCPKG_DETECTED_MSVC_VERSION LESS "1925" AND VCPKG_DETECTED_CMAKE_C_COMPILER_ID STREQUAL "MSVC")
    list(APPEND FEATURE_OPTIONS
        -DLLVM_TEMPORARILY_ALLOW_OLD_TOOLCHAIN=ON
    )
endif()

# Force enable or disable external libraries
set(llvm_external_libraries
    zlib
    libxml2
    zstd
)
foreach(external_library IN LISTS llvm_external_libraries)
    string(TOLOWER "enable-${external_library}" feature_name)
    string(TOUPPER "LLVM_ENABLE_${external_library}" define_name)
    if(feature_name IN_LIST FEATURES)
        list(APPEND FEATURE_OPTIONS
            -D${define_name}=FORCE_ON
        )
    else()
        list(APPEND FEATURE_OPTIONS
            -D${define_name}=OFF
        )
    endif()
endforeach()

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
# By default in LLVM, abi-breaking checks are enabled if assertions are enabled.
# however, this breaks linking with the debug versions, since the option is
# baked into the header files; thus, we always turn off LLVM_ABI_BREAKING_CHECKS
# unless the user asks for it
if("enable-abi-breaking-checks" IN_LIST FEATURES)
    # Force enable abi-breaking checks.
    list(APPEND FEATURE_OPTIONS
        -DLLVM_ABI_BREAKING_CHECKS=FORCE_ON
    )
else()
    # Force disable abi-breaking checks.
    list(APPEND FEATURE_OPTIONS
        -DLLVM_ABI_BREAKING_CHECKS=FORCE_OFF
    )
endif()

set(LLVM_ENABLE_PROJECTS)
if("bolt" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "bolt")
endif()
if("clang" IN_LIST FEATURES OR "clang-tools-extra" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "clang")
    if("disable-clang-static-analyzer" IN_LIST FEATURES)
        list(APPEND FEATURE_OPTIONS
            # Disable ARCMT
            -DCLANG_ENABLE_ARCMT=OFF
            # Disable static analyzer
            -DCLANG_ENABLE_STATIC_ANALYZER=OFF
        )
    endif()
    # 1) LLVM/Clang tools are relocated from ./bin/ to ./tools/llvm/ (LLVM_TOOLS_INSTALL_DIR=tools/llvm)
    # 2) Clang resource files are relocated from ./lib/clang/<version> to ./tools/llvm/lib/clang/<version> (see patch 0007-fix-compiler-rt-install-path.patch)
    # So, the relative path should be changed from ../lib/clang/<version> to ./lib/clang/<version>
    list(APPEND FEATURE_OPTIONS -DCLANG_RESOURCE_DIR=lib/clang/${VERSION})
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
if("clang-tools-extra" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "clang-tools-extra")
endif()
if("compiler-rt" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "compiler-rt")
endif()
if("flang" IN_LIST FEATURES)
    if(VCPKG_DETECTED_CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" AND VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        message(FATAL_ERROR "Building Flang with MSVC is not supported on x86. Disable it until issues are fixed.")
    endif()
    list(APPEND LLVM_ENABLE_PROJECTS "flang")
    list(APPEND FEATURE_OPTIONS
        # Flang requires C++17
        -DCMAKE_CXX_STANDARD=17
    )
endif()
if("libclc" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "libclc")
endif()
if("lld" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "lld")
endif()
if("lldb" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "lldb")
    list(APPEND FEATURE_OPTIONS
        -DLLDB_ENABLE_CURSES=OFF
    )
endif()
if("mlir" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "mlir")
    if("enable-mlir-python-bindings" IN_LIST FEATURES)
        list(APPEND FEATURE_OPTIONS
            -DMLIR_ENABLE_BINDINGS_PYTHON=ON
            "-Dpybind11_DIR=${CURRENT_INSTALLED_DIR}/share/pybind11"
        )
    endif()
endif()
if("openmp" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "openmp")
    # Perl is required for the OpenMP run-time
    vcpkg_find_acquire_program(PERL)
    get_filename_component(PERL_PATH ${PERL} DIRECTORY)
    vcpkg_add_to_path(${PERL_PATH})
    # Skip post-build check
    set(VCPKG_POLICY_SKIP_DUMPBIN_CHECKS enabled)
endif()
if("polly" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "polly")
endif()
if("pstl" IN_LIST FEATURES)
    if(VCPKG_DETECTED_CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        message(FATAL_ERROR "Building pstl with MSVC is not supported. Disable it until issues are fixed.")
    endif()
    list(APPEND LLVM_ENABLE_PROJECTS "pstl")
endif()

set(LLVM_ENABLE_RUNTIMES)
if("libcxx" IN_LIST FEATURES)
    if(VCPKG_DETECTED_CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        message(FATAL_ERROR "Building libcxx with MSVC is not supported, as cl doesn't support the #include_next extension.")
    endif()
    list(APPEND LLVM_ENABLE_RUNTIMES "libcxx")
endif()
if("libcxxabi" IN_LIST FEATURES)
    if(VCPKG_DETECTED_CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        message(FATAL_ERROR "Building libcxxabi with MSVC is not supported. Disable it until issues are fixed.")
    endif()
    list(APPEND LLVM_ENABLE_RUNTIMES "libcxxabi")
endif()
if("libunwind" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_RUNTIMES "libunwind")
endif()

# this is for normal targets
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
    VE
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

# this is for experimental targets
set(known_llvm_experimental_targets
    SPRIV
)

set(LLVM_EXPERIMENTAL_TARGETS_TO_BUILD "")
foreach(llvm_target IN LISTS known_llvm_experimental_targets)
    string(TOLOWER "target-${llvm_target}" feature_name)
    if(feature_name IN_LIST FEATURES)
        list(APPEND LLVM_EXPERIMENTAL_TARGETS_TO_BUILD "${llvm_target}")
    endif()
endforeach()

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON3_DIR ${PYTHON3} DIRECTORY)
vcpkg_add_to_path("${PYTHON3_DIR}")

set(LLVM_LINK_JOBS 1)

file(REMOVE "${SOURCE_PATH}/llvm/cmake/modules/Findzstd.cmake")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/llvm"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DLLVM_INCLUDE_EXAMPLES=OFF
        -DLLVM_BUILD_EXAMPLES=OFF
        -DLLVM_INCLUDE_TESTS=OFF
        -DLLVM_BUILD_TESTS=OFF
        -DLLVM_INCLUDE_BENCHMARKS=OFF
        -DLLVM_BUILD_BENCHMARKS=OFF
        -DLIBOMP_INSTALL_ALIASES=OFF
        -DLLVM_INCLUDE_DOCS=OFF
        -DLLVM_BUILD_DOCS=OFF
        -DLLVM_INCLUDE_RUNTIMES=OFF
        -DLLVM_BUILD_RUNTIME=OFF
        -DLLVM_BUILD_RUNTIMES=OFF
        -DLLVM_ENABLE_DIA_SDK=OFF
        -DLLVM_ENABLE_OCAMLDOC=OFF
        # Force TableGen to be built with optimization. This will significantly improve build time.
        -DLLVM_OPTIMIZED_TABLEGEN=ON
        "-DLLVM_ENABLE_PROJECTS=${LLVM_ENABLE_PROJECTS}"
        "-DLLVM_ENABLE_RUNTIMES=${LLVM_ENABLE_RUNTIMES}"
        "-DLLVM_TARGETS_TO_BUILD=${LLVM_TARGETS_TO_BUILD}"
        "-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=${LLVM_EXPERIMENTAL_TARGETS_TO_BUILD}"

        -DPACKAGE_VERSION=${VERSION}
        # Limit the maximum number of concurrent link jobs to 1. This should fix low amount of memory issue for link.
        "-DLLVM_PARALLEL_LINK_JOBS=${LLVM_LINK_JOBS}"
        -DLLVM_TOOLS_INSTALL_DIR:PATH=tools/llvm
        -DCLANG_TOOLS_INSTALL_DIR:PATH=tools/llvm
        -DLLD_TOOLS_INSTALL_DIR:PATH=tools/llvm
        -DMLIR_TOOLS_INSTALL_DIR:PATH=tools/llvm
        -DBOLT_TOOLS_INSTALL_DIR:PATH=tools/llvm # all others are strings
        -DOPENMP_TOOLS_INSTALL_DIR:PATH=tools/llvm
    MAYBE_UNUSED_VARIABLES 
        COMPILER_RT_ENABLE_IOS
        OPENMP_TOOLS_INSTALL_DIR
        MLIR_TOOLS_INSTALL_DIR
)

vcpkg_cmake_install(ADD_BIN_TO_PATH)

function(llvm_cmake_package_config_fixup package_name)
    cmake_parse_arguments("arg" "DO_NOT_DELETE_PARENT_CONFIG_PATH" "FEATURE_NAME;CONFIG_PATH" "" ${ARGN})
    if(NOT DEFINED arg_FEATURE_NAME)
        set(arg_FEATURE_NAME ${package_name})
    endif()
    if("${arg_FEATURE_NAME}" STREQUAL "${PORT}" OR "${arg_FEATURE_NAME}" IN_LIST FEATURES)
        set(args)
        list(APPEND args PACKAGE_NAME "${package_name}")
        if(arg_DO_NOT_DELETE_PARENT_CONFIG_PATH)
            list(APPEND args "DO_NOT_DELETE_PARENT_CONFIG_PATH")
        endif()
        if(arg_CONFIG_PATH)
            list(APPEND args "CONFIG_PATH" "${arg_CONFIG_PATH}")
        endif()
        vcpkg_cmake_config_fixup(${args})
        file(INSTALL "${SOURCE_PATH}/${arg_FEATURE_NAME}/LICENSE.TXT" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${package_name}" RENAME copyright)
        if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/${package_name}_usage")
            file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/${package_name}_usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${package_name}" RENAME usage)
        endif()
    endif()
endfunction()

llvm_cmake_package_config_fixup("clang" DO_NOT_DELETE_PARENT_CONFIG_PATH)
llvm_cmake_package_config_fixup("flang" DO_NOT_DELETE_PARENT_CONFIG_PATH)
llvm_cmake_package_config_fixup("lld" DO_NOT_DELETE_PARENT_CONFIG_PATH)
llvm_cmake_package_config_fixup("mlir" DO_NOT_DELETE_PARENT_CONFIG_PATH)
llvm_cmake_package_config_fixup("polly" DO_NOT_DELETE_PARENT_CONFIG_PATH)
llvm_cmake_package_config_fixup("ParallelSTL" FEATURE_NAME "pstl" DO_NOT_DELETE_PARENT_CONFIG_PATH CONFIG_PATH "lib/cmake/ParallelSTL")
llvm_cmake_package_config_fixup("llvm")

set(empty_dirs)

if("clang-tools-extra" IN_LIST FEATURES)
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/clang-tidy/plugin")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/clang-tidy/misc/ConfusableTable")
endif()

if("pstl" IN_LIST FEATURES)
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/lib/cmake")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/debug/lib/cmake")
endif()

if("flang" IN_LIST FEATURES)
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/Config")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/CMakeFiles")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/Optimizer/CMakeFiles")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/Optimizer/CodeGen/CMakeFiles")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/Optimizer/Dialect/CMakeFiles")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/Optimizer/Transforms/CMakeFiles")
endif()

if(empty_dirs)
    foreach(empty_dir IN LISTS empty_dirs)
        if(NOT EXISTS "${empty_dir}")
            message(SEND_ERROR "Directory '${empty_dir}' is not exist. Please remove it from the checking.")
        else()
            file(GLOB_RECURSE files_in_dir "${empty_dir}/*")
            if(files_in_dir)
                message(SEND_ERROR "Directory '${empty_dir}' is not empty. Please remove it from the checking.")
            else()
                file(REMOVE_RECURSE "${empty_dir}")
            endif()
        endif()
    endforeach()
endif()

vcpkg_copy_tool_dependencies(${CURRENT_PACKAGES_DIR}/tools/${PORT})

if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
        "${CURRENT_PACKAGES_DIR}/debug/share"
        "${CURRENT_PACKAGES_DIR}/debug/tools"
    )
endif()

if("mlir" IN_LIST FEATURES)
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/mlir/MLIRConfig.cmake" "set(MLIR_MAIN_SRC_DIR \"${SOURCE_PATH}/mlir\")" "")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/mlir/MLIRConfig.cmake" "${CURRENT_BUILDTREES_DIR}" "\${MLIR_INCLUDE_DIRS}")
endif()

# LLVM still generates a few DLLs in the static build:
# * LLVM-C.dll
# * libclang.dll
# * LTO.dll
# * Remarks.dll
set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
