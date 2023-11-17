cmake_minimum_required(VERSION 3.21)

include(CMakePrintHelpers)

set(BUILD_CXX_LANGUAGE_PACKAGE OFF CACHE BOOL "Add C and C++ support to the Sourcetrail indexer.")
if(BUILD_CXX_LANGUAGE_PACKAGE)
	list(APPEND VCPKG_MANIFEST_FEATURES "cpp")
endif()

set(BUILD_JAVA_LANGUAGE_PACKAGE OFF CACHE BOOL "Add Java support to the Sourcetrail indexer.")
if(BUILD_JAVA_LANGUAGE_PACKAGE)
	list(APPEND VCPKG_MANIFEST_FEATURES "java")
endif()

set(BUILD_PYTHON_LANGUAGE_PACKAGE OFF CACHE BOOL "Add Python support to the Sourcetrail indexer.")
if(BUILD_PYTHON_LANGUAGE_PACKAGE)
	list(APPEND VCPKG_MANIFEST_FEATURES "python")
endif()

set(DOCKER_BUILD OFF CACHE BOOL "Build runs in Docker")

set(TREAT_WARNINGS_AS_ERRORS ON CACHE BOOL "Treat compiler warnings as errors")

#set (CMAKE_VERBOSE_MAKEFILE ON)

find_program(BASH_EXECUTABLE bash REQUIRED
	PATHS $ENV{ProgramFiles}/Git/bin /usr/bin /bin
	NO_DEFAULT_PATH
)
message (STATUS "Found Bash: ${BASH_EXECUTABLE}")

include(cmake/add_files.cmake)
include(cmake/create_source_groups.cmake)
include(cmake/version.cmake)
include(cmake/version_setup.cmake)
include(cmake/licenses.cmake)

# prohibit in-source-builds
if (${CMAKE_BINARY_DIR} STREQUAL ${CMAKE_SOURCE_DIR})
	message(STATUS "In-source-builds are not allowed")
	message(STATUS "Clean your source directory (e.g. delete the CMakeCache.txt file)")
	message(FATAL_ERROR "Please create a separate build directory and call CMake again")
endif()

if(NOT DEFINED CMAKE_CXX_COMPILER_LAUNCHER)
	# speed up recompiling on unix with ccache
	find_program(CCACHE_PROGRAM ccache)
	if (CCACHE_PROGRAM)
		message(STATUS "ccache found")
		# Support Unix Makefiles and Ninja
		set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}" CACHE STRING "Compiler launcher for CXX")
	endif()
endif()

# Variables --------------------------------------------------------------------

set(PROJECT_NAME Sourcetrail)

set(APP_PROJECT_NAME "${PROJECT_NAME}")
set(APP_INDEXER_NAME "${PROJECT_NAME}_indexer")
set(LIB_UTILITY_PROJECT_NAME "${PROJECT_NAME}_lib_utility")
set(LIB_GUI_PROJECT_NAME "${PROJECT_NAME}_lib_gui")
set(LIB_CXX_PROJECT_NAME "${PROJECT_NAME}_lib_cxx")
set(LIB_JAVA_PROJECT_NAME "${PROJECT_NAME}_lib_java")
set(LIB_PYTHON_PROJECT_NAME "${PROJECT_NAME}_lib_python")
set(LIB_PROJECT_NAME "${PROJECT_NAME}_lib")
set(TEST_PROJECT_NAME "${PROJECT_NAME}_test")

# Project ----------------------------------------------------------------------

project(${PROJECT_NAME})

# CMAKE_SYSTEM_NAME available after project

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	set(PLATFORM_INCLUDE "includesWindows.h")
elseif (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
	set(PLATFORM_INCLUDE "includesMac.h")
elseif (CMAKE_SYSTEM_NAME STREQUAL "Linux")
	set(PLATFORM_INCLUDE "includesLinux.h")
endif ()

# set Standard build type to Release
set(CMAKE_BUILD_TYPE_INIT "Release")

#RPATH
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
	set(CMAKE_SKIP_BUILD_RPATH FALSE)
	set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
	set(CMAKE_INSTALL_RPATH "$ORIGIN/lib/:$$ORIGIN/lib/")
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 11)


# Settings ---------------------------------------------------------------------

if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "AppleClang")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-unknown-warning-option -fcolor-diagnostics -fvisibility-inlines-hidden")
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
	ADD_COMPILE_OPTIONS(/MP)
	ADD_COMPILE_OPTIONS(/utf-8)
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
	# FIXME: necessary to fix build in Docker
	if (DOCKER_BUILD)
		set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libstdc++")
	endif()
endif()

if (TREAT_WARNINGS_AS_ERRORS)
	if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
		# Visual Studio 2017 version 15.9 <= Version <= Visual Studio 2022 Version 17.X
		if ((MSVC_VERSION GREATER_EQUAL 1916) AND (MSVC_TOOLSET_VERSION LESS_EQUAL 143))
			# Warning 4003: not enough actual parameters for macro 'identifier'
			# Warning 4250: 'class1' inherits 'class2::member' via dominance
			set(WARNINGS_LIST "/wd4003 /wd4250")
			set(CMAKE_CXX_WARNINGS_FLAGS "/experimental:external /external:anglebrackets /external:W0 /WX")
			set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_WARNINGS_FLAGS} ${WARNINGS_LIST}")

			# Treat linker warnings as errors
			set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /WX")
			set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /WX")
			set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /WX")
			set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} /WX")

			message(STATUS "'Treat warnings as errors' policy is enabled")
		else()
			message(STATUS "'Treat warnings as errors' policy is disabled")
		endif()
	else()
		message(STATUS "'Treat warnings as errors' policy is disabled")
	endif()
endif()

# For debugging the release build on linux
#if (CMAKE_SYSTEM_NAME STREQUAL "Linux" AND "$<CONFIG>" STREQUAL "Release")
	#add_definitions(-fno-omit-frame-pointer)
#endif ()


# Clang ------------------------------------------------------------------------

if (BUILD_CXX_LANGUAGE_PACKAGE)

	find_package(LLVM 11 REQUIRED)
	find_package(Clang REQUIRED)

	if (LLVM_FOUND)
		message(STATUS "Found LLVM ${LLVM_VERSION}")
	endif()

	set (_CLANG_HEADERS_SEARCH_LIST
		"${LLVM_LIBRARY_DIR}/clang/${LLVM_VERSION}/include"
		"${LLVM_LIBRARY_DIR}/clang/${LLVM_VERSION_MAJOR}/include"
	)
	foreach (_CLANG_HEADER_PATH ${_CLANG_HEADERS_SEARCH_LIST})
		if (EXISTS ${_CLANG_HEADER_PATH})
			set (CLANG_COMPILER_HEADER_SEARCH_PATH ${_CLANG_HEADER_PATH})
			break ()
		endif ()
	endforeach ()

	if (EXISTS ${CLANG_COMPILER_HEADER_SEARCH_PATH})
		message (STATUS "Found Clang compiler headers in directory '${CLANG_COMPILER_HEADER_SEARCH_PATH}'.")
		file(GLOB_RECURSE CLANG_COMPILER_HEADER_PATHS RELATIVE "${CLANG_COMPILER_HEADER_SEARCH_PATH}" "${CLANG_COMPILER_HEADER_SEARCH_PATH}/*")
		foreach(CLANG_COMPILER_HEADER_PATH ${CLANG_COMPILER_HEADER_PATHS})
			configure_file("${CLANG_COMPILER_HEADER_SEARCH_PATH}/${CLANG_COMPILER_HEADER_PATH}" "${CMAKE_SOURCE_DIR}/bin/app/data/cxx/include/${CLANG_COMPILER_HEADER_PATH}" COPYONLY)
		endforeach()
	else ()
		message(FATAL_ERROR "Unable to copy Clang compiler headers from clang build dir.")
	endif ()

endif()


# Boost ------------------------------------------------------------------------

set(Boost_USE_MULTITHREAD ON)
set(Boost_USE_STATIC_LIBS ON CACHE BOOL "Set to ON to force the use of the static libraries.")
set(Boost_USE_STATIC_RUNTIME OFF)

find_package(Boost 1.67 REQUIRED COMPONENTS
	system
	program_options
	filesystem
	date_time
)

# Qt ---------------------------------------------------------------------------

set (QT_MIN_VERSION "5.12.0")
set (QT_MIN_VERSION_HEX 0x051200)
find_package(Qt5 ${QT_MIN_VERSION} REQUIRED COMPONENTS
	 Core Gui Widgets Network Svg
)

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	find_package(Qt5 ${QT_MIN_VERSION} COMPONENTS WinExtras REQUIRED)
endif()

if(Qt5Widgets_FOUND)
	message(STATUS "Found Qt ${Qt5Widgets_VERSION_STRING}")

	# FIX: Qt was built with -reduce-relocations
	if (Qt5_POSITION_INDEPENDENT_CODE)
		SET(CMAKE_POSITION_INDEPENDENT_CODE ON)
	endif()

	# The following define makes your compiler emit warnings if you use
	# any feature of Qt which as been marked as deprecated (the exact warnings
	# depend on your compiler). Please consult the documentation of the
	# deprecated API in order to know how to port your code away from it.
	add_definitions (-DQT_DEPRECATED_WARNINGS)

	# You can also make your code fail to compile if you use deprecated APIs.
	# In order to do so, uncomment the following line.
	# You can also select to disable deprecated APIs only up to a certain version of Qt.
	#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=${QT_MIN_VERSION_HEX}    # disables all the APIs deprecated at or before the specified Qt version
	add_definitions (-DQT_DISABLE_DEPRECATED_BEFORE=${QT_MIN_VERSION_HEX})
endif()


# Setup ---------------------------------------------------------------------------

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	configure_file("${CMAKE_SOURCE_DIR}/setup/icon/windows/sourcetrail.ico" "${CMAKE_BINARY_DIR}/sourcetrail.ico" COPYONLY)
endif()


add_subdirectory(src/app)
add_subdirectory(src/external)
add_subdirectory(src/indexer)
add_subdirectory(src/lib)
add_subdirectory(src/lib_cxx)
add_subdirectory(src/lib_gui)
add_subdirectory(src/lib_java)
add_subdirectory(src/lib_python)
add_subdirectory(src/lib_utility)
add_subdirectory(src/test)


# Lib Utility ------------------------------------------------------------------

add_library(${LIB_UTILITY_PROJECT_NAME} ${LIB_UTILITY_FILES})

create_source_groups(${LIB_UTILITY_FILES})

set_property(
	TARGET ${LIB_UTILITY_PROJECT_NAME}
	PROPERTY INCLUDE_DIRECTORIES
		"${LIB_UTILITY_INCLUDE_PATHS}"
)

target_include_directories(${LIB_UTILITY_PROJECT_NAME} SYSTEM
	PUBLIC ${Boost_INCLUDE_DIR}
)

target_link_libraries(${LIB_UTILITY_PROJECT_NAME} ${Boost_LIBRARIES} Qt5::Widgets Qt5::Network)

if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
	find_package(Threads REQUIRED)
	target_link_libraries(${LIB_UTILITY_PROJECT_NAME} ${CMAKE_DL_LIBS} rt ${CMAKE_THREAD_LIBS_INIT})
endif()

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	target_link_libraries(${LIB_UTILITY_PROJECT_NAME} Qt5::WinExtras)
endif()


# Lib --------------------------------------------------------------------------

set_source_files_properties(${EXTERNAL_FILES} PROPERTIES COMPILE_FLAGS "-w")
set_source_files_properties(${EXTERNAL_C_FILES} PROPERTIES COMPILE_FLAGS "-std=gnu89 -w")

add_library(${LIB_PROJECT_NAME} ${LIB_FILES} ${EXTERNAL_FILES} ${EXTERNAL_C_FILES})

create_source_groups(${LIB_FILES})
create_source_groups(${EXTERNAL_FILES})
create_source_groups(${EXTERNAL_C_FILES})

set_property(
	TARGET ${LIB_PROJECT_NAME}
	PROPERTY INCLUDE_DIRECTORIES
		"${LIB_INCLUDE_PATHS}"
		"${LIB_GUI_INCLUDE_PATHS}"
		"${LIB_UTILITY_INCLUDE_PATHS}"
		"${LIB_CXX_INCLUDE_PATHS}"
		"${LIB_JAVA_INCLUDE_PATHS}"
		"${CMAKE_BINARY_DIR}/src/lib"
)

target_include_directories(${LIB_PROJECT_NAME} SYSTEM
	PUBLIC ${Boost_INCLUDE_DIR}
	"${EXTERNAL_INCLUDE_PATHS}"
	"${EXTERNAL_C_INCLUDE_PATHS}"
)

target_link_libraries(${LIB_PROJECT_NAME} ${LIB_UTILITY_PROJECT_NAME} ${LIB_GUI_PROJECT_NAME} ${Boost_LIBRARIES} $<$<PLATFORM_ID:Windows>:bcrypt>)

#configure language package defines
configure_file(
	"${CMAKE_SOURCE_DIR}/cmake/language_packages.h.in"
	"${CMAKE_BINARY_DIR}/src/lib/language_packages.h"
)


# Lib Cxx ----------------------------------------------------------------------

if (BUILD_CXX_LANGUAGE_PACKAGE)

	set(CAPTURED_CMAKE_CXX_STANDARD ${CMAKE_CXX_STANDARD})
	set(CMAKE_CXX_STANDARD 17) # Respect to LLVM_REQUIRED_CXX_STANDARD
	
	add_library(${LIB_CXX_PROJECT_NAME} ${LIB_CXX_FILES})

	create_source_groups(${LIB_CXX_FILES})

	set_property(
		TARGET ${LIB_CXX_PROJECT_NAME}
		PROPERTY INCLUDE_DIRECTORIES
			"${LIB_CXX_INCLUDE_PATHS}"
			"${LIB_UTILITY_INCLUDE_PATHS}"
			"${LIB_INCLUDE_PATHS}"
			"${CMAKE_BINARY_DIR}/src/lib"
	)

	target_include_directories(${LIB_CXX_PROJECT_NAME} SYSTEM
		PUBLIC ${LLVM_INCLUDE_DIRS}
		${CLANG_INCLUDE_DIRS}
		${Boost_INCLUDE_DIRS}
		"${EXTERNAL_INCLUDE_PATHS}"
		"${EXTERNAL_C_INCLUDE_PATHS}"
	)

	link_directories(${LLVM_LIBRARY_DIRS} ${CLANG_LIBRARY_DIRS} ${Boost_LIBRARY_DIRS})

	if(CLANG_LINK_CLANG_DYLIB)
		set(REQ_LLVM_LIBS LLVM)
	else()
		llvm_map_components_to_libnames(REQ_LLVM_LIBS
			BinaryFormat
			BitstreamReader
			Core
			Demangle
			FrontendOpenMP
			LibDriver
			MC
			MCParser
			Option
			ProfileData
			Remarks
			Support
			TextAPI
		)

		foreach(LLVM_TARGET ${LLVM_TARGETS_TO_BUILD})
			if("LLVM${LLVM_TARGET}CodeGen" IN_LIST LLVM_AVAILABLE_LIBS)
				get_property(lib_deps GLOBAL PROPERTY "LLVMBUILD_LIB_DEPS_LLVM${LLVM_TARGET}CodeGen")
				list(APPEND REQ_LLVM_LIBS "LLVM${LLVM_TARGET}CodeGen")
				list(APPEND REQ_LLVM_LIBS "${lib_deps}")
			endif()

			if("LLVM${LLVM_TARGET}AsmParser" IN_LIST LLVM_AVAILABLE_LIBS)
				get_property(lib_deps GLOBAL PROPERTY "LLVMBUILD_LIB_DEPS_LLVM${LLVM_TARGET}AsmParser")
				list(APPEND REQ_LLVM_LIBS "LLVM${LLVM_TARGET}AsmParser")
				list(APPEND REQ_LLVM_LIBS "${lib_deps}")
			endif()
		endforeach()
	endif()

	if(CLANG_LINK_CLANG_DYLIB)
		set(REQ_CLANG_LIBS clang-cpp)
	else()
		set(REQ_CLANG_LIBS
			clangAnalysis
			clangAST
			clangBasic
			clangDriver
			clangEdit
			clangFrontend
			clangLex
			clangParse
			clangSema
			clangSerialization
			clangTooling
		)
	endif()

	target_link_libraries(${LIB_CXX_PROJECT_NAME} ${LIB_UTILITY_PROJECT_NAME} ${REQ_CLANG_LIBS} ${REQ_LLVM_LIBS})

	if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
		target_compile_definitions(${LIB_CXX_PROJECT_NAME} PRIVATE _SILENCE_ALL_CXX17_DEPRECATION_WARNINGS) # Due to Clang
		target_link_libraries(${LIB_CXX_PROJECT_NAME} version)
	endif()

	set(CMAKE_CXX_STANDARD ${CAPTURED_CMAKE_CXX_STANDARD})
else()

	message(STATUS "Building the Cxx indexer will be skipped. You can enable building this target by setting 'BUILD_CXX_LANGUAGE_PACKAGE' to 'ON'.")

endif()


# Lib Java ---------------------------------------------------------------------

if (BUILD_JAVA_LANGUAGE_PACKAGE)

	find_package(JNI)

	add_library(${LIB_JAVA_PROJECT_NAME} ${LIB_JAVA_FILES})

	create_source_groups(${LIB_JAVA_FILES})

	set_property(
		TARGET ${LIB_JAVA_PROJECT_NAME}
		PROPERTY INCLUDE_DIRECTORIES
			"${LIB_JAVA_INCLUDE_PATHS}"
			"${LIB_UTILITY_INCLUDE_PATHS}"
			"${LIB_INCLUDE_PATHS}"
			"${LIB_GUI_INCLUDE_PATHS}"
			"${CMAKE_BINARY_DIR}/src/lib"
	)

	target_include_directories(${LIB_JAVA_PROJECT_NAME} SYSTEM
		PUBLIC ${JNI_INCLUDE_DIRS}
		${Boost_INCLUDE_DIRS}
	)

	link_directories(${Boost_LIBRARY_DIRS})

	target_link_libraries(${LIB_JAVA_PROJECT_NAME} ${LIB_UTILITY_PROJECT_NAME} ${LIB_PROJECT_NAME})

	add_custom_command(
		TARGET ${LIB_JAVA_PROJECT_NAME}
		PRE_BUILD
		COMMAND ${BASH_EXECUTABLE} ${PROJECT_SOURCE_DIR}/script/update_java_indexer.sh
		COMMENT "updating java indexer jars"
	)

else()

	message(STATUS "Building the Java indexer will be skipped. You can enable building this target by setting 'BUILD_JAVA_LANGUAGE_PACKAGE' to 'ON'.")

endif()


# Lib Python ---------------------------------------------------------------------

if (BUILD_PYTHON_LANGUAGE_PACKAGE)

	add_library(${LIB_PYTHON_PROJECT_NAME} ${LIB_PYTHON_FILES})

	create_source_groups(${LIB_PYTHON_FILES})

	set_property(
		TARGET ${LIB_PYTHON_PROJECT_NAME}
		PROPERTY INCLUDE_DIRECTORIES
			"${LIB_PYTHON_INCLUDE_PATHS}"
			"${LIB_UTILITY_INCLUDE_PATHS}"
			"${LIB_INCLUDE_PATHS}"
			"${CMAKE_BINARY_DIR}/src/lib"
	)

	#link_directories(${Boost_LIBRARY_DIRS})

	target_link_libraries(${LIB_PYTHON_PROJECT_NAME} ${LIB_UTILITY_PROJECT_NAME} ${LIB_PROJECT_NAME})

	add_custom_command(
		TARGET ${LIB_PYTHON_PROJECT_NAME}
		PRE_BUILD
		COMMAND ${BASH_EXECUTABLE} ${PROJECT_SOURCE_DIR}/script/download_python_indexer.sh
		COMMENT "download python indexer"
	)

else()

	message(STATUS "Building the Python indexer will be skipped. You can enable building this target by setting 'BUILD_PYTHON_LANGUAGE_PACKAGE' to 'ON'.")

endif()


# Lib Gui ----------------------------------------------------------------------

# Find includes in corresponding build directories
set(CMAKE_INCLUDE_CURRENT_DIR ON)
# Instruct CMake to run moc automatically when needed.
set(CMAKE_AUTOMOC ON)

# target for running versionnumber script
# workaround for running customcommand (ninja dependency cycle)
add_custom_target(
	versionnumber ALL
)

add_library(${LIB_GUI_PROJECT_NAME} ${LIB_GUI_FILES} ${CMAKE_BINARY_DIR}/src/lib_gui/productVersion.h)

target_link_libraries(${LIB_GUI_PROJECT_NAME} ${LIB_UTILITY_PROJECT_NAME} ${LIB_PROJECT_NAME} Qt5::Widgets Qt5::Network Qt5::Svg)

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	target_link_libraries(${LIB_GUI_PROJECT_NAME} Qt5::WinExtras)
endif()

# command for versioning script
add_custom_command(
	TARGET versionnumber
	PRE_BUILD
	COMMAND ${CMAKE_COMMAND} -DBINARY_DIR=${CMAKE_BINARY_DIR} -P ${CMAKE_SOURCE_DIR}/cmake/version.cmake
	BYPRODUCTS ${CMAKE_BINARY_DIR}/src/lib_gui/productVersion.h
	DEPENDS ${LIB_GUI_PROJECT_NAME}
	WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
	COMMENT "check/update version number"
)
add_dependencies(${LIB_GUI_PROJECT_NAME} versionnumber)

create_source_groups(${LIB_GUI_FILES})

set_property(
	TARGET ${LIB_GUI_PROJECT_NAME}
	PROPERTY INCLUDE_DIRECTORIES
		"${LIB_GUI_INCLUDE_PATHS}"
		"${LIB_UTILITY_INCLUDE_PATHS}"
		"${LIB_INCLUDE_PATHS}"
		"${CMAKE_BINARY_DIR}/src/lib_gui"
		"${CMAKE_BINARY_DIR}/src/lib"
		$<$<BOOL:${BUILD_CXX_LANGUAGE_PACKAGE}>:${LIB_CXX_INCLUDE_PATHS}>
		$<$<BOOL:${BUILD_JAVA_LANGUAGE_PACKAGE}>:${LIB_JAVA_INCLUDE_PATHS}>
		$<$<BOOL:${BUILD_PYTHON_LANGUAGE_PACKAGE}>:${LIB_PYTHON_INCLUDE_PATHS}>
)

# include external header without warnings
target_include_directories(${LIB_GUI_PROJECT_NAME} SYSTEM
	PUBLIC ${Boost_INCLUDE_DIRS}
	"${EXTERNAL_INCLUDE_PATHS}"
	"${EXTERNAL_C_INCLUDE_PATHS}"
)

# configure platform specific include file
configure_file(
	"${PROJECT_SOURCE_DIR}/src/lib_gui/platform_includes/includes.h.in"
	"${PROJECT_BINARY_DIR}/src/lib_gui/includes.h"
)

#configure the versioning file
configure_file(
	${CMAKE_SOURCE_DIR}/cmake/version.txt.in
	${CMAKE_BINARY_DIR}/version.txt
)

configure_file(
	${CMAKE_SOURCE_DIR}/cmake/productVersion.h.in
	${CMAKE_BINARY_DIR}/src/lib_gui/productVersion.h
)

set_property(SOURCE ${CMAKE_BINARY_DIR}/src/lib_gui/productVersion.h PROPERTY SKIP_AUTOMOC ON)

set(CMAKE_AUTOMOC OFF)


# Indexer App ------------------------------------------------------------------

if (NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
	set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/app/")
else ()
	foreach( CONFIGURATION_TYPE ${CMAKE_CONFIGURATION_TYPES} )
		string( TOUPPER ${CONFIGURATION_TYPE} CONFIG )
		set( CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CONFIG} "${CMAKE_BINARY_DIR}/${CONFIGURATION_TYPE}/app/")
	endforeach()
endif ()

# Find includes in corresponding build directories
set(CMAKE_INCLUDE_CURRENT_DIR ON)

add_executable(${APP_INDEXER_NAME} ${INDEXER_FILES})


set_target_properties(${APP_INDEXER_NAME} PROPERTIES OUTPUT_NAME sourcetrail_indexer)

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	# hide the console when running a release build.
	set_target_properties(${APP_INDEXER_NAME} PROPERTIES LINK_FLAGS_DEBUG "/SUBSYSTEM:CONSOLE /DEBUG:FASTLINK")
	set_target_properties(${APP_INDEXER_NAME} PROPERTIES COMPILE_DEFINITIONS_DEBUG "_CONSOLE")
	set_target_properties(${APP_INDEXER_NAME} PROPERTIES LINK_FLAGS_RELWITHDEBINFO "/SUBSYSTEM:CONSOLE")
	set_target_properties(${APP_INDEXER_NAME} PROPERTIES COMPILE_DEFINITIONS_RELWITHDEBINFO "_CONSOLE")
	set_target_properties(${APP_INDEXER_NAME} PROPERTIES LINK_FLAGS_RELEASE "/ENTRY:\"mainCRTStartup\" /SUBSYSTEM:WINDOWS /DEBUG")
	set_target_properties(${APP_INDEXER_NAME} PROPERTIES LINK_FLAGS_MINSIZEREL "/SUBSYSTEM:WINDOWS")

	# generate pdb for release build
	set (CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /Zi")
endif ()

create_source_groups(${INDEXER_FILES})

target_link_libraries(
	${APP_INDEXER_NAME}
	${LIB_GUI_PROJECT_NAME}
	$<$<BOOL:${BUILD_CXX_LANGUAGE_PACKAGE}>:${LIB_CXX_PROJECT_NAME}>
	$<$<BOOL:${BUILD_JAVA_LANGUAGE_PACKAGE}>:${LIB_JAVA_PROJECT_NAME}>
	$<$<BOOL:${BUILD_PYTHON_LANGUAGE_PACKAGE}>:${LIB_PYTHON_PROJECT_NAME}>
	${LIB_PROJECT_NAME}
)

if (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
	find_library(CORE_FOUNDATION CoreFoundation)
	target_link_libraries(${APP_INDEXER_NAME} ${CORE_FOUNDATION})
endif ()

set_property(
	TARGET ${APP_INDEXER_NAME}
	PROPERTY INCLUDE_DIRECTORIES
		"${APP_INCLUDE_PATHS}"
		"${LIB_INCLUDE_PATHS}"
		"${LIB_UTILITY_INCLUDE_PATHS}"
		"${LIB_GUI_INCLUDE_PATHS}"
		"${CMAKE_BINARY_DIR}/src/lib_gui"
		"${CMAKE_BINARY_DIR}/src/lib"
		$<$<BOOL:${BUILD_CXX_LANGUAGE_PACKAGE}>:${LIB_CXX_INCLUDE_PATHS}>
		$<$<BOOL:${BUILD_JAVA_LANGUAGE_PACKAGE}>:${LIB_JAVA_INCLUDE_PATHS}>
		$<$<BOOL:${BUILD_PYTHON_LANGUAGE_PACKAGE}>:${LIB_PYTHON_INCLUDE_PATHS}>
)


# App --------------------------------------------------------------------------

if (NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
	set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/app/")
else ()
	foreach( CONFIGURATION_TYPE ${CMAKE_CONFIGURATION_TYPES} )
		string( TOUPPER ${CONFIGURATION_TYPE} CONFIG )
		set( CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CONFIG} "${CMAKE_BINARY_DIR}/${CONFIGURATION_TYPE}/app/")
	endforeach()
endif ()

# Find includes in corresponding build directories
set(CMAKE_INCLUDE_CURRENT_DIR ON)

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	file(WRITE ${CMAKE_BINARY_DIR}/Sourcetrail.rc
		"// Icon with lowest ID value placed first to ensure application icon\n"
		"// remains consistent on all systems.\n"
		"IDI_ICON1               ICON                    \"${CMAKE_BINARY_DIR}/Sourcetrail.ico\"\n"
	)

	add_executable(${APP_PROJECT_NAME} ${APP_FILES} ${CMAKE_BINARY_DIR}/Sourcetrail.rc)

	# also show the console when running a release build.
	set_target_properties(${APP_PROJECT_NAME} PROPERTIES LINK_FLAGS_DEBUG "/SUBSYSTEM:CONSOLE /DEBUG:FASTLINK")
	set_target_properties(${APP_PROJECT_NAME} PROPERTIES COMPILE_DEFINITIONS_DEBUG "_CONSOLE")
	set_target_properties(${APP_PROJECT_NAME} PROPERTIES LINK_FLAGS_RELWITHDEBINFO "/SUBSYSTEM:CONSOLE")
	set_target_properties(${APP_PROJECT_NAME} PROPERTIES COMPILE_DEFINITIONS_RELWITHDEBINFO "_CONSOLE")
	set_target_properties(${APP_PROJECT_NAME} PROPERTIES LINK_FLAGS_RELEASE "/ENTRY:\"mainCRTStartup\" /SUBSYSTEM:CONSOLE /DEBUG")
	set_target_properties(${APP_PROJECT_NAME} PROPERTIES LINK_FLAGS_MINSIZEREL "/SUBSYSTEM:CONSOLE")

	# generate pdb for release build
	set (CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /Zi")

	set_property(
		TARGET ${APP_PROJECT_NAME}
			PROPERTY VS_DEBUGGER_WORKING_DIRECTORY
			"${CMAKE_SOURCE_DIR}/bin/app")

	string(REGEX REPLACE "/" "\\\\" BACKSLASHED_CMAKE_BINARY_DIR ${CMAKE_BINARY_DIR})
	string(REGEX REPLACE "/" "\\\\" BACKSLASHED_CMAKE_SOURCE_DIR ${CMAKE_SOURCE_DIR})
else ()
	add_executable(${APP_PROJECT_NAME} ${APP_FILES})
endif ()

create_source_groups(${APP_FILES})

target_link_libraries(
	${APP_PROJECT_NAME}
	${LIB_GUI_PROJECT_NAME}
	$<$<BOOL:${BUILD_CXX_LANGUAGE_PACKAGE}>:${LIB_CXX_PROJECT_NAME}>
	$<$<BOOL:${BUILD_JAVA_LANGUAGE_PACKAGE}>:${LIB_JAVA_PROJECT_NAME}>
	$<$<BOOL:${BUILD_PYTHON_LANGUAGE_PACKAGE}>:${LIB_PYTHON_PROJECT_NAME}>
	${LIB_PROJECT_NAME}
)

set_property(
	TARGET ${APP_PROJECT_NAME}
	PROPERTY INCLUDE_DIRECTORIES
		"${APP_INCLUDE_PATHS}"
		"${LIB_INCLUDE_PATHS}"
		"${LIB_UTILITY_INCLUDE_PATHS}"
		"${LIB_GUI_INCLUDE_PATHS}"
		"${CMAKE_BINARY_DIR}/src/lib_gui"
		"${CMAKE_BINARY_DIR}/src/lib"
		$<$<BOOL:${BUILD_CXX_LANGUAGE_PACKAGE}>:${LIB_CXX_INCLUDE_PATHS}>
		$<$<BOOL:${BUILD_JAVA_LANGUAGE_PACKAGE}>:${LIB_JAVA_INCLUDE_PATHS}>
		$<$<BOOL:${BUILD_PYTHON_LANGUAGE_PACKAGE}>:${LIB_PYTHON_INCLUDE_PATHS}>
)

target_include_directories(${APP_PROJECT_NAME} SYSTEM
	PUBLIC ${Boost_INCLUDE_DIRS}
	"${EXTERNAL_INCLUDE_PATHS}"
	"${EXTERNAL_C_INCLUDE_PATHS}"
)

# Use the Widgets module from Qt 5
target_link_libraries(${APP_PROJECT_NAME} Qt5::Widgets Qt5::Network)

# add platform specific libraries
if (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
	find_library(CORE_FOUNDATION CoreFoundation)
	target_link_libraries(${APP_PROJECT_NAME} ${CORE_FOUNDATION})
endif ()

add_dependencies(${APP_PROJECT_NAME} ${APP_INDEXER_NAME})


# macOS Bundle ----------------------------------------------------------------

if (CMAKE_SYSTEM_NAME STREQUAL "Darwin")

	set(MACOS_BUNDLE_NAME ${PROJECT_NAME})
	set(MACOS_BUNDLE_VERSION ${VERSION_STRING})
	set(MACOS_BINARY_NAME ${APP_PROJECT_NAME})
	set(MACOS_INDEXER_BINARY_NAME ${APP_INDEXER_NAME})

	get_property(QT_CORE_PATH TARGET ${Qt5Core_LIBRARIES} PROPERTY LOCATION)
	get_filename_component(QT_CORE_PATH ${QT_CORE_PATH} REALPATH)

	get_property(QT_GUI_PATH TARGET ${Qt5Gui_LIBRARIES} PROPERTY LOCATION)
	get_filename_component(QT_GUI_PATH ${QT_GUI_PATH} REALPATH)

	get_property(QT_WIDGETS_PATH TARGET ${Qt5Widgets_LIBRARIES} PROPERTY LOCATION)
	get_filename_component(QT_WIDGETS_PATH ${QT_WIDGETS_PATH} REALPATH)

	get_property(QT_NETWORK_PATH TARGET ${Qt5Network_LIBRARIES} PROPERTY LOCATION)
	get_filename_component(QT_NETWORK_PATH ${QT_NETWORK_PATH} REALPATH)

	get_property(QT_SVG_PATH TARGET ${Qt5Svg_LIBRARIES} PROPERTY LOCATION)
	get_filename_component(QT_SVG_PATH ${QT_SVG_PATH} REALPATH)

	list(APPEND MACOS_QT_FRAMEWORKS ${QT_CORE_PATH} ${QT_GUI_PATH} ${QT_WIDGETS_PATH} ${QT_PRINT_PATH} ${QT_NETWORK_PATH} ${QT_SVG_PATH})
	string(REPLACE ";" " " MACOS_QT_FRAMEWORKS "${MACOS_QT_FRAMEWORKS}")

	set(MACOS_BOOST_DIR "${Boost_INCLUDE_DIR}")
	STRING(REGEX REPLACE "/lib/cmake/clang" "" MACOS_CLANG_DIR "${Clang_DIR}")
	STRING(REGEX REPLACE "/lib/cmake/Qt5" "" MACOS_QT_DIR "${Qt5_DIR}")

	configure_file(
		${PROJECT_SOURCE_DIR}/setup/macOS/bundle_install.sh.in
		${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/bundle_install.sh
		@ONLY
	)

	configure_file(
		${PROJECT_SOURCE_DIR}/setup/macOS/bundle_info.plist.in
		${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/bundle_info.plist
		@ONLY
	)

endif ()


# Test ----------------------------------------------------------------------

if (NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
	set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/test/")
else ()
	foreach( CONFIGURATION_TYPE ${CMAKE_CONFIGURATION_TYPES} )
		string( TOUPPER ${CONFIGURATION_TYPE} CONFIG )
		set( CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CONFIG} "${CMAKE_BINARY_DIR}/${CONFIGURATION_TYPE}/test/")
	endforeach()
endif ()

add_executable (${TEST_PROJECT_NAME} ${TEST_FILES})

create_source_groups(${TEST_FILES})

target_link_libraries(
	${TEST_PROJECT_NAME}
	${LIB_GUI_PROJECT_NAME}
	$<$<BOOL:${BUILD_CXX_LANGUAGE_PACKAGE}>:${LIB_CXX_PROJECT_NAME}>
	$<$<BOOL:${BUILD_JAVA_LANGUAGE_PACKAGE}>:${LIB_JAVA_PROJECT_NAME}>
	$<$<BOOL:${BUILD_PYTHON_LANGUAGE_PACKAGE}>:${LIB_PYTHON_PROJECT_NAME}>
	${LIB_PROJECT_NAME}
	${LIB_GUI_PROJECT_NAME}
	$<$<BOOL:${BUILD_CXX_LANGUAGE_PACKAGE}>:${LIB_CXX_PROJECT_NAME}>
	$<$<BOOL:${BUILD_JAVA_LANGUAGE_PACKAGE}>:${LIB_JAVA_PROJECT_NAME}>
	$<$<BOOL:${BUILD_PYTHON_LANGUAGE_PACKAGE}>:${LIB_PYTHON_PROJECT_NAME}>
)

set_property(
	TARGET ${TEST_PROJECT_NAME}
	PROPERTY INCLUDE_DIRECTORIES
		"${TEST_INCLUDE_PATHS}"
		"${LIB_INCLUDE_PATHS}"
		"${LIB_UTILITY_INCLUDE_PATHS}"
		"${LIB_GUI_INCLUDE_PATHS}"
		"${EXTERNAL_INCLUDE_PATHS}"
		"${EXTERNAL_C_INCLUDE_PATHS}"
		"${Boost_INCLUDE_DIRS}"
		"${CMAKE_BINARY_DIR}/src/lib"
		$<$<BOOL:${BUILD_CXX_LANGUAGE_PACKAGE}>:${LIB_CXX_INCLUDE_PATHS}>
		$<$<BOOL:${BUILD_JAVA_LANGUAGE_PACKAGE}>:${LIB_JAVA_INCLUDE_PATHS}>
		$<$<BOOL:${BUILD_PYTHON_LANGUAGE_PACKAGE}>:${LIB_PYTHON_INCLUDE_PATHS}>
)

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	set_target_properties(${TEST_PROJECT_NAME} PROPERTIES COMPILE_FLAGS "/bigobj")
	set_property(
		TARGET ${TEST_PROJECT_NAME}
			PROPERTY VS_DEBUGGER_WORKING_DIRECTORY
			"${CMAKE_SOURCE_DIR}/bin/test")
endif ()

if (NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
	add_custom_command(
		COMMENT "create symlink:"
		TARGET ${APP_PROJECT_NAME}
		PRE_BUILD
		COMMAND "${CMAKE_COMMAND}" "-E" "make_directory" "${CMAKE_BINARY_DIR}/app"
		COMMAND "${CMAKE_COMMAND}" "-E" "make_directory" "${CMAKE_BINARY_DIR}/test"
		COMMAND "${CMAKE_COMMAND}" "-E" "create_symlink"
			"${CMAKE_SOURCE_DIR}/bin/app/data"
			"${CMAKE_BINARY_DIR}/app/data"
		COMMAND "${CMAKE_COMMAND}" "-E" "create_symlink"
			"${CMAKE_SOURCE_DIR}/bin/app/user"
			"${CMAKE_BINARY_DIR}/app/user"
		COMMAND "${CMAKE_COMMAND}" "-E" "create_symlink"
			"${CMAKE_SOURCE_DIR}/bin/test/data"
			"${CMAKE_BINARY_DIR}/test/data"
		VERBATIM
	)
else()
	add_custom_command(
		COMMENT "create symlink:"
		TARGET ${APP_PROJECT_NAME}
		PRE_BUILD
		COMMAND "${CMAKE_COMMAND}" "-E" "make_directory" "${CMAKE_BINARY_DIR}/$<CONFIG>/app"
		COMMAND "${CMAKE_COMMAND}" "-E" "make_directory" "${CMAKE_BINARY_DIR}/$<CONFIG>/test"
		COMMAND "cmd.exe" "/k"
			IF NOT EXIST "${BACKSLASHED_CMAKE_BINARY_DIR}\\$<CONFIG>\\app\\data"
			"mklink" "/d" "/j"
			"${BACKSLASHED_CMAKE_BINARY_DIR}\\$<CONFIG>\\app\\data"
			"${BACKSLASHED_CMAKE_SOURCE_DIR}\\bin\\app\\data"
		COMMAND "cmd.exe" "/k"
			IF NOT EXIST "${BACKSLASHED_CMAKE_BINARY_DIR}\\$<CONFIG>\\app\\user" 
			"mklink" "/d" "/j" 
			"${BACKSLASHED_CMAKE_BINARY_DIR}\\$<CONFIG>\\app\\user"
			"${BACKSLASHED_CMAKE_SOURCE_DIR}\\bin\\app\\user"
		COMMAND "cmd.exe" "/k"
			IF NOT EXIST "${BACKSLASHED_CMAKE_BINARY_DIR}\\$<CONFIG>\\test\\data" 
			"mklink" "/d" "/j"
			"${BACKSLASHED_CMAKE_BINARY_DIR}\\$<CONFIG>\\test\\data"
			"${BACKSLASHED_CMAKE_SOURCE_DIR}\\bin\\test\\data"
		VERBATIM
	)
endif ()


# Install ----------------------------------------------------------------------

set(VCPKG_APPLOCAL_DEPS ON)
set(X_VCPKG_APPLOCAL_DEPS_INSTALL OFF)

get_target_property(QMAKE_EXECUTABLE Qt5::qmake IMPORTED_LOCATION)

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	include(cmake/installdirs/windows.cmake)
elseif (CMAKE_SYSTEM_NAME STREQUAL "Linux")
	include(cmake/installdirs/linux.cmake)
elseif (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
	include(cmake/installdirs/macos.cmake)
endif()

# Use relative DESTINATION for package

install(
	TARGETS
		${APP_PROJECT_NAME}
		${APP_INDEXER_NAME}
	RUNTIME_DEPENDENCY_SET deps
	BUNDLE
		DESTINATION ${INSTALL_BIN_DIR}
	RUNTIME
		DESTINATION ${INSTALL_BIN_DIR}
		COMPONENT Executables
)

if (BUILD_CXX_LANGUAGE_PACKAGE)
	install(CODE "
		# Index sample projects, execute sequentially
		execute_process(
			COMMAND
				$<TARGET_FILE:${APP_PROJECT_NAME}> index --full ${CMAKE_SOURCE_DIR}/bin/app/user/projects/tictactoe_cpp/tictactoe_cpp.srctrlprj
			WORKING_DIRECTORY
				$<TARGET_FILE_DIR:${APP_PROJECT_NAME}>
			COMMAND_ECHO STDOUT
			COMMAND_ERROR_IS_FATAL ANY
		)
		execute_process(
			COMMAND
				$<TARGET_FILE:${APP_PROJECT_NAME}> index --full ${CMAKE_SOURCE_DIR}/bin/app/user/projects/tutorial/tutorial.srctrlprj
			WORKING_DIRECTORY
				$<TARGET_FILE_DIR:${APP_PROJECT_NAME}>
			COMMAND_ECHO STDOUT
			COMMAND_ERROR_IS_FATAL ANY
		)
		"
		COMPONENT Resources
	)
endif()

if (BUILD_JAVA_LANGUAGE_PACKAGE)
	install(CODE "
		# Index sample projects, execute sequentially
		execute_process(
			COMMAND
				$<TARGET_FILE:${APP_PROJECT_NAME}> index --full ${CMAKE_SOURCE_DIR}/bin/app/user/projects/javaparser/javaparser.srctrlprj
			WORKING_DIRECTORY
				$<TARGET_FILE_DIR:${APP_PROJECT_NAME}>
			COMMAND_ECHO STDOUT
			COMMAND_ERROR_IS_FATAL ANY
		)
		"
		COMPONENT Resources
	)
endif()

if (BUILD_PYTHON_LANGUAGE_PACKAGE)
	install(CODE "
		# Index sample projects, execute sequentially
		execute_process(
			COMMAND
				$<TARGET_FILE:${APP_PROJECT_NAME}> index --full ${CMAKE_SOURCE_DIR}/bin/app/user/projects/tictactoe_py/tictactoe_py.srctrlprj
			WORKING_DIRECTORY
				$<TARGET_FILE_DIR:${APP_PROJECT_NAME}>
			COMMAND_ECHO STDOUT
			COMMAND_ERROR_IS_FATAL ANY
		)
		"
		COMPONENT Resources
	)
endif()

install(
	DIRECTORY
		${CMAKE_SOURCE_DIR}/bin/app/data
		${CMAKE_SOURCE_DIR}/bin/app/user
	DESTINATION ${INSTALL_DATA_DIR}
	COMPONENT Resources
	FILES_MATCHING PATTERN "*"
	REGEX "/__pycache__/" EXCLUDE
	REGEX "/data/install/" EXCLUDE
	REGEX "/user/log/" EXCLUDE
	REGEX "/user/ApplicationSettings.xml" EXCLUDE
	REGEX "/user/window_settings.ini" EXCLUDE
	PATTERN "*_template.xml" EXCLUDE
)

include(cmake/qt/qt5_macros.cmake)

qt5_generate_deploy_script(
	TARGET ${APP_PROJECT_NAME}
	OUTPUT_SCRIPT QT_INSTALL_SCRIPT
	CONTENT "
		qt5_deploy_runtime_dependencies(
			EXECUTABLES 
				$<TARGET_FILE:${APP_PROJECT_NAME}>
				$<TARGET_FILE:${APP_INDEXER_NAME}>
			BIN_DIR ${INSTALL_BIN_DIR}
			LIB_DIR ${INSTALL_LIB_DIR}
			PLUGINS_DIR ${INSTALL_PLUGINS_DIR}
		)
	"
)

install(SCRIPT ${QT_INSTALL_SCRIPT}
	COMPONENT Qt
)

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	install(
		FILES
			"${CMAKE_SOURCE_DIR}/setup/qt/windows/qt.conf"
		DESTINATION ${INSTALL_BIN_DIR}
		COMPONENT Qt
	)

	if(CMAKE_CL_64)
		set(VC_TOOLS_REDIST_DIR "$ENV{VCToolsRedistDir}/x64/Microsoft.VC${MSVC_TOOLSET_VERSION}.CRT")
		set(WINDOWS_SDK_DIR "$ENV{WindowsSdkDir}/Redist/$ENV{WindowsSDKVersion}/ucrt/DLLs/x64")
	else()
		set(VC_TOOLS_REDIST_DIR "$ENV{VCToolsRedistDir}/x86/Microsoft.VC${MSVC_TOOLSET_VERSION}.CRT")
		set(WINDOWS_SDK_DIR "$ENV{WindowsSdkDir}/Redist/$ENV{WindowsSDKVersion}/ucrt/DLLs/x86")
	endif()

	cmake_path(NORMAL_PATH VC_TOOLS_REDIST_DIR)

	cmake_path(NORMAL_PATH WINDOWS_SDK_DIR)

	install(RUNTIME_DEPENDENCY_SET deps
		DIRECTORIES
			${VC_TOOLS_REDIST_DIR}
			${WINDOWS_SDK_DIR}
		PRE_INCLUDE_REGEXES 
			"^ucrtbase\\.dll$"
			"^api-ms-win-.*\\.dll$"
			"^vccorlib140.*\\.dll$"
			"^msvcp140.*\\.dll$"
			"^vcruntime140.*\\.dll$"
			"^libeay32\\.dll$"
			"^ssleay32\\.dll$"
		PRE_EXCLUDE_REGEXES 
			".*"
		POST_INCLUDE_REGEXES
			"^.*/ucrtbase\\.dll$"
			"^.*/api-ms-win-.*\\.dll$"
			"^.*/vccorlib140.*\\.dll$"
			"^.*/msvcp140.*\\.dll$"
			"^.*/vcruntime140.*\\.dll$"
			"^.*/libeay32\\.dll$"
			"^.*/ssleay32\\.dll$"
		POST_EXCLUDE_REGEXES 
			".*"
		RUNTIME
			DESTINATION ${INSTALL_BIN_DIR}
			COMPONENT DLLs
	)
elseif (CMAKE_SYSTEM_NAME STREQUAL "Linux")

elseif (CMAKE_SYSTEM_NAME STREQUAL "Darwin")

endif()


# Package ----------------------------------------------------------------------

set(CPACK_SET_DESTDIR "OFF")

set(CPACK_PACKAGE_DIRECTORY "${CMAKE_SOURCE_DIR}/distr/packages")

set(CPACK_PACKAGE_VENDOR "Active")

set(CPACK_PACKAGE_NAME "Sourcetrail")

set(CPACK_PACKAGE_VERSION_MAJOR "${VERSION_YEAR}")
set(CPACK_PACKAGE_VERSION_MINOR "${VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH "${VERSION_COMMIT}")
set(CPACK_PACKAGE_VERSION "${VERSION_STRING}")

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
	set(BITS 64)
else()
	set(BITS 32)
endif()

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_VENDOR}-${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-Windows-${BITS}bit")
elseif (CMAKE_SYSTEM_NAME STREQUAL "Linux")
	set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_VENDOR}-${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-Linux-${BITS}bit")
elseif (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
	set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_VENDOR}-${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-macOS-${BITS}bit")
endif()

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
	set(CPACK_GENERATOR "External")
	set(CPACK_EXTERNAL_PACKAGE_SCRIPT "${CMAKE_BINARY_DIR}/CPackExternal.cmake")
	set(CPACK_EXTERNAL_ENABLE_STAGING YES)
	configure_file(
		"${CMAKE_SOURCE_DIR}/cmake/package/windows.cmake.in"
		"${CMAKE_BINARY_DIR}/package_windows.cmake.generate.in"
		@ONLY
	)
	file(GENERATE
		OUTPUT "${CMAKE_BINARY_DIR}/CPackExternal.cmake"
		INPUT "${CMAKE_BINARY_DIR}/package_windows.cmake.generate.in"
	)

elseif (CMAKE_SYSTEM_NAME STREQUAL "Linux")
	set(CPACK_GENERATOR "External")
	set(CPACK_EXTERNAL_PACKAGE_SCRIPT "${CMAKE_BINARY_DIR}/CPackExternal.cmake")
	set(CPACK_EXTERNAL_ENABLE_STAGING YES)
	configure_file(
		"${CMAKE_SOURCE_DIR}/cmake/package/linux.cmake.in"
		"${CMAKE_BINARY_DIR}/package_linux.cmake.generate.in"
		@ONLY
	)
	file(GENERATE
		OUTPUT "${CMAKE_BINARY_DIR}/CPackExternal.cmake"
		INPUT "${CMAKE_BINARY_DIR}/package_linux.cmake.generate.in"
	)

elseif (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
	set(CPACK_GENERATOR "External")
	set(CPACK_EXTERNAL_PACKAGE_SCRIPT "${CMAKE_BINARY_DIR}/CPackExternal.cmake")
	set(CPACK_EXTERNAL_ENABLE_STAGING YES)
	configure_file(
		"${CMAKE_SOURCE_DIR}/cmake/package/macos.cmake.in"
		"${CMAKE_BINARY_DIR}/package_macos.cmake.generate.in"
		@ONLY
	)
	file(GENERATE
		OUTPUT "${CMAKE_BINARY_DIR}/CPackExternal.cmake"
		INPUT "${CMAKE_BINARY_DIR}/package_macos.cmake.generate.in"
	)

endif()

set(CPACK_SOURCE_GENERATOR "ZIP")
set(CPACK_SOURCE_PACKAGE_FILE_NAME "${CPACK_PACKAGE_VENDOR}-${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-Source")
set(CPACK_SOURCE_IGNORE_FILES "/build/;/distr/;/vcpkg/;/\\\\.git/;/\\\\.vs/")

include(CPack)
