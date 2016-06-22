# CMakeLists.txt

# Copyright (C) 2007-2015 Glenn Randers-Pehrson

# This code is released under the libpng license.
# For conditions of distribution and use, see the disclaimer
# and license in png.h

cmake_minimum_required(VERSION 2.8.12 FATAL_ERROR)

set(CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS true)

# some init settings
set(CMAKE_COLOR_MAKEFILE ON)
# set path to additional CMake modules
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})


project(libpng C)

include(GNUInstallDirs)

set(INSTALL_BIN_DIR ${CMAKE_INSTALL_BINDIR} CACHE INTERNAL "Installation directory for executables" FORCE)
set(INSTALL_LIB_DIR ${CMAKE_INSTALL_LIBDIR} CACHE INTERNAL "Installation directory for libraries" FORCE)
set(INSTALL_INC_DIR ${CMAKE_INSTALL_INCLUDEDIR} CACHE INTERNAL "Installation directory for headers" FORCE)
set(INSTALL_MAN_DIR ${CMAKE_INSTALL_MANDIR} CACHE INTERNAL "Installation directory for man files" FORCE)

if(CMAKE_GENERATOR_TOOLSET MATCHES "v([0-9]+)_xp")
    add_definitions(-D_WIN32_WINNT=0x0501)
endif()

include(util)

check_version(PNGLIB_MAJOR PNGLIB_MINOR PNGLIB_RELEASE)

set(PNGLIB_NAME libpng${PNGLIB_MAJOR}${PNGLIB_MINOR})
set(PNGLIB_VERSION ${PNGLIB_MAJOR}.${PNGLIB_MINOR}.${PNGLIB_RELEASE})

report_version(${PROJECT_NAME} ${PNGLIB_VERSION})

configure_file(${CMAKE_SOURCE_DIR}/cmake/cmake_uninstall.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake IMMEDIATE @ONLY)


# needed packages
include(FindAnyProject)
find_anyproject(ZLIB REQUIRED)

if(NOT WIN32)
  find_library(M_LIBRARY
    NAMES m
    PATHS /usr/lib /usr/local/lib
  )
  if(NOT M_LIBRARY)
    message(STATUS "math lib 'libm' not found; floating point support disabled")
  endif()
else()
  # not needed on windows
  set(M_LIBRARY "")
endif()

set(TARGET_LINK_LIB ${TARGET_LINK_LIB} ${M_LIBRARY})

# COMMAND LINE OPTIONS
if(BUILD_SHARED_LIBS)
    set(PNG_SHARED ON)
else()
    set(PNG_STATIC ON)
endif()

# Many more configuration options could be added here
option(PNG_FRAMEWORK "Build OS X framework" OFF)
option(PNG_DEBUG     "Build with debug output" OFF)
option(PNGARG        "Disable ANSI-C prototypes" OFF)

# SET LIBNAME
set(PNG_LIB_NAME png${PNGLIB_MAJOR}${PNGLIB_MINOR})

# to distinguish between debug and release lib
set(CMAKE_DEBUG_POSTFIX "d")

# Use the prebuilt pnglibconf.h file from the scripts folder
# TODO: fix this by building with awk; without this no cmake build can be
# configured directly (to do so indirectly use your local awk to build a
# pnglibconf.h in the build directory.)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/pnglibconf.h.prebuilt
               ${CMAKE_CURRENT_BINARY_DIR}/pnglibconf.h)
include_directories(${CMAKE_CURRENT_BINARY_DIR})

# OUR SOURCES
set(libpng_public_hdrs
  png.h
  pngconf.h
  ${CMAKE_CURRENT_BINARY_DIR}/pnglibconf.h
)
set(libpng_sources
  ${libpng_public_hdrs}
  pngdebug.h
  pnginfo.h
  pngpriv.h
  pngstruct.h
  png.c
  pngerror.c
  pngget.c
  pngmem.c
  pngpread.c
  pngread.c
  pngrio.c
  pngrtran.c
  pngrutil.c
  pngset.c
  pngtrans.c
  pngwio.c
  pngwrite.c
  pngwtran.c
  pngwutil.c
)

if(CMAKE_CROSSCOMPILING AND NEON)
    set(libpng_sources ${libpng_sources}
        arm/arm_init.c
        arm/filter_neon.S 
        arm/filter_neon_intrinsics.c
    )
endif()
# SOME NEEDED DEFINITIONS

if(MSVC)
  add_definitions(-D_CRT_SECURE_NO_DEPRECATE)
endif(MSVC)

if(PNG_DEBUG)
  add_definitions(-DPNG_DEBUG)
endif()

# NOW BUILD OUR TARGET
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

unset(PNG_LIB_TARGETS)

if(PNG_SHARED)
  add_library(${PNG_LIB_NAME} SHARED ${libpng_sources})
  set(PNG_LIB_TARGETS ${PNG_LIB_NAME})
  if(MSVC)
    # msvc does not append 'lib' - do it here to have consistent name
    set_target_properties(${PNG_LIB_NAME} PROPERTIES PREFIX "lib")
    set_target_properties(${PNG_LIB_NAME} PROPERTIES IMPORT_PREFIX "lib")
  endif()
  target_link_extlibraries(${PNG_LIB_NAME})
endif()

if(PNG_STATIC)
    if(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX)
        set( CMAKE_CXX_FLAGS "-fpic ${CMAKE_CXX_FLAGS}" )
        set( CMAKE_C_FLAGS   "-fpic ${CMAKE_C_FLAGS}" )  
    endif()
  # does not work without changing name
  set(PNG_LIB_NAME_STATIC ${PNG_LIB_NAME}_static)
  add_library(${PNG_LIB_NAME_STATIC} STATIC ${libpng_sources})
  list(APPEND PNG_LIB_TARGETS ${PNG_LIB_NAME_STATIC})
  if(MSVC)
    # msvc does not append 'lib' - do it here to have consistent name
    set_target_properties(${PNG_LIB_NAME_STATIC} PROPERTIES PREFIX "lib")
  endif()
  target_link_extlibraries(${PNG_LIB_NAME_STATIC})
endif()

if(PNG_FRAMEWORK)
  set(PNG_LIB_NAME_FRAMEWORK ${PNG_LIB_NAME}_framework)
  add_library(${PNG_LIB_NAME_FRAMEWORK} SHARED ${libpng_sources})
  list(APPEND PNG_LIB_TARGETS ${PNG_LIB_NAME_FRAMEWORK})
  set_target_properties(${PNG_LIB_NAME_FRAMEWORK} PROPERTIES
    FRAMEWORK TRUE
    FRAMEWORK_VERSION ${PNGLIB_VERSION}
    MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${PNGLIB_MAJOR}.${PNGLIB_MINOR}
    MACOSX_FRAMEWORK_BUNDLE_VERSION ${PNGLIB_VERSION}
    MACOSX_FRAMEWORK_IDENTIFIER org.libpng.libpng
    XCODE_ATTRIBUTE_INSTALL_PATH "@rpath"
    PUBLIC_HEADER "${libpng_public_hdrs}"
    OUTPUT_NAME png)
  target_link_extlibraries(${PNG_LIB_NAME_FRAMEWORK})
endif()

if(NOT PNG_LIB_TARGETS)
  message(SEND_ERROR
    "No library variant selected to build. "
    "Please enable at least one of the following options: "
    " PNG_STATIC, PNG_SHARED, PNG_FRAMEWORK")
endif()

if(BUILD_SHARED_LIBS)
    set(EXPORT_NAME ${PROJECT_NAME})
else()
    set(EXPORT_NAME ${PROJECT_NAME}static)
endif()    
export(TARGETS ${PNG_LIB_TARGETS} FILE ${EXPORT_NAME}-exports.cmake EXPORT_LINK_INTERFACE_LIBRARIES)

if(PNG_SHARED AND WIN32)
  set_target_properties(${PNG_LIB_NAME} PROPERTIES DEFINE_SYMBOL PNG_BUILD_DLL)
endif()



# Ensure the CMAKE_LIBRARY_OUTPUT_DIRECTORY is set
IF(NOT CMAKE_LIBRARY_OUTPUT_DIRECTORY)
  SET(CMAKE_LIBRARY_OUTPUT_DIRECTORY "lib")
ENDIF(NOT CMAKE_LIBRARY_OUTPUT_DIRECTORY)

# Set a variable with CMake code which:
# Creates a symlink from src to dest (if possible) or alternatively
# copies if different.
macro(CREATE_SYMLINK SRC_FILE DEST_FILE)
  FILE(REMOVE ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${DEST_FILE})
  if(WIN32 AND NOT CYGWIN AND NOT MSYS)
    ADD_CUSTOM_COMMAND(
        OUTPUT ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${DEST_FILE}   ${CMAKE_CURRENT_BINARY_DIR}/${DEST_FILE}
        COMMAND ${CMAKE_COMMAND} -E copy_if_different  "${SRC_FILE}" ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${DEST_FILE}
        COMMAND ${CMAKE_COMMAND} -E copy_if_different  "${SRC_FILE}" ${CMAKE_CURRENT_BINARY_DIR}/${DEST_FILE}
        DEPENDS ${PNG_LIB_TARGETS}
        )
    ADD_CUSTOM_TARGET(${DEST_FILE}_COPY ALL DEPENDS ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${DEST_FILE})
  else(WIN32 AND NOT CYGWIN AND NOT MSYS)
#    get_filename_component(LINK_TARGET "${SRC_FILE}" NAME)
#    execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
#    execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink "${LINK_TARGET}" ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${DEST_FILE} WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
#    execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink "${LINK_TARGET}" ${DEST_FILE} WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
    ADD_CUSTOM_COMMAND(
        OUTPUT ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${DEST_FILE}   ${CMAKE_CURRENT_BINARY_DIR}/${DEST_FILE}
        COMMAND ${CMAKE_COMMAND} -E copy_if_different  "${SRC_FILE}" ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${DEST_FILE}
        COMMAND ${CMAKE_COMMAND} -E copy_if_different  "${SRC_FILE}" ${CMAKE_CURRENT_BINARY_DIR}/${DEST_FILE}
        DEPENDS ${PNG_LIB_TARGETS}
        )
    ADD_CUSTOM_TARGET(${DEST_FILE}_COPY ALL DEPENDS ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${DEST_FILE})
  endif(WIN32 AND NOT CYGWIN AND NOT MSYS)
endmacro()

# libpng is a library so default to 'lib'
if(NOT DEFINED CMAKE_INSTALL_LIBDIR)
  set(CMAKE_INSTALL_LIBDIR lib)
endif(NOT DEFINED CMAKE_INSTALL_LIBDIR)

# CREATE PKGCONFIG FILES
# we use the same files like ./configure, so we have to set its vars
# Only do this on Windows for Cygwin - the files don't make much sense outside
# a UNIX look alike
if(NOT WIN32 OR CYGWIN OR MINGW)
  set(prefix      ${CMAKE_INSTALL_PREFIX})
  set(exec_prefix ${CMAKE_INSTALL_PREFIX})
  set(libdir      ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR})
  set(includedir  ${CMAKE_INSTALL_PREFIX}/include)
  set(LIBS        "-lz -lm")
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/libpng.pc.in
    ${CMAKE_CURRENT_BINARY_DIR}/${PNGLIB_NAME}.pc @ONLY)
  CREATE_SYMLINK(${PNGLIB_NAME}.pc libpng.pc)

  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/libpng-config.in
    ${CMAKE_CURRENT_BINARY_DIR}/${PNGLIB_NAME}-config @ONLY)
  CREATE_SYMLINK(${PNGLIB_NAME}-config libpng-config)
endif(NOT WIN32 OR CYGWIN OR MINGW)

# SET UP LINKS
if(PNG_SHARED)
  set_target_properties(${PNG_LIB_NAME} PROPERTIES
#   VERSION 16.${PNGLIB_RELEASE}.1.6.21
    VERSION 16.${PNGLIB_RELEASE}.0
    SOVERSION 16
    CLEAN_DIRECT_OUTPUT 1)
endif()
if(PNG_STATIC)
  # MSVC doesn't use a different file extension for shared vs. static
  # libs.  We are able to change OUTPUT_NAME to remove the _static
  # for all other platforms.
  if(NOT MSVC)
    set_target_properties(${PNG_LIB_NAME_STATIC} PROPERTIES
      OUTPUT_NAME ${PNG_LIB_NAME}
      CLEAN_DIRECT_OUTPUT 1)
  endif()
endif()

# If CMake > 2.4.x, we set a variable used below to export
# targets to an export file.
# TODO: Use VERSION_GREATER after our cmake_minimum_required >= 2.6.2
if(CMAKE_MAJOR_VERSION GREATER 1 AND CMAKE_MINOR_VERSION GREATER 4)
  set(PNG_EXPORT_RULE EXPORT libpng)
elseif(CMAKE_MAJOR_VERSION GREATER 2) # future proof
  set(PNG_EXPORT_RULE EXPORT libpng)
endif()

# INSTALL
if(NOT SKIP_INSTALL_LIBRARIES AND NOT SKIP_INSTALL_ALL )
  install(TARGETS ${PNG_LIB_TARGETS}
      ${PNG_EXPORT_RULE}
      RUNTIME DESTINATION ${INSTALL_BIN_DIR}
      LIBRARY DESTINATION ${INSTALL_LIB_DIR}
      ARCHIVE DESTINATION ${INSTALL_LIB_DIR}
      FRAMEWORK DESTINATION ${INSTALL_LIB_DIR})
      
  if(CMAKE_VERSION VERSION_EQUAL "3.0.0" OR
    CMAKE_VERSION VERSION_GREATER "3.0.0")
    CMAKE_POLICY(SET CMP0026 OLD)
  endif()

  if(PNG_SHARED)
    # Create a symlink for libpng.dll.a => libpng16.dll.a on Cygwin
    if(CYGWIN OR MINGW)
       get_target_property(BUILD_TARGET_LOCATION ${PNG_LIB_NAME} LOCATION_${CMAKE_BUILD_TYPE})
       CREATE_SYMLINK(${BUILD_TARGET_LOCATION} libpng${CMAKE_IMPORT_LIBRARY_SUFFIX})
       install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libpng${CMAKE_IMPORT_LIBRARY_SUFFIX}
         DESTINATION ${INSTALL_LIB_DIR})
    endif(CYGWIN OR MINGW)

    if(NOT WIN32)
      get_target_property(BUILD_TARGET_LOCATION ${PNG_LIB_NAME} LOCATION_${CMAKE_BUILD_TYPE})
      CREATE_SYMLINK(${BUILD_TARGET_LOCATION} libpng${CMAKE_SHARED_LIBRARY_SUFFIX})
      install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libpng${CMAKE_SHARED_LIBRARY_SUFFIX}
         DESTINATION ${INSTALL_LIB_DIR})
    endif(NOT WIN32)
  endif(PNG_SHARED)

  if(PNG_STATIC)
    if(NOT WIN32 OR CYGWIN OR MINGW)
      get_target_property(BUILD_TARGET_LOCATION ${PNG_LIB_NAME_STATIC} LOCATION_${CMAKE_BUILD_TYPE})
      CREATE_SYMLINK(${BUILD_TARGET_LOCATION} libpng${CMAKE_STATIC_LIBRARY_SUFFIX})
      install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libpng${CMAKE_STATIC_LIBRARY_SUFFIX}
         DESTINATION ${INSTALL_LIB_DIR})
    endif(NOT WIN32 OR CYGWIN OR MINGW)
 endif()
endif()

if(NOT SKIP_INSTALL_HEADERS AND NOT SKIP_INSTALL_ALL )
  install(FILES ${libpng_public_hdrs}   DESTINATION ${INSTALL_INC_DIR})
  install(FILES ${libpng_public_hdrs}   DESTINATION ${INSTALL_INC_DIR}/${PNGLIB_NAME})
endif()
if(NOT SKIP_INSTALL_EXECUTABLES AND NOT SKIP_INSTALL_ALL )
  if(NOT WIN32 OR CYGWIN OR MINGW)
    install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/libpng-config DESTINATION ${INSTALL_BIN_DIR})
    install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/${PNGLIB_NAME}-config
            DESTINATION ${INSTALL_BIN_DIR})
  endif(NOT WIN32 OR CYGWIN OR MINGW)
endif()

if(NOT SKIP_INSTALL_FILES AND NOT SKIP_INSTALL_ALL )
  # Install man pages
  if(NOT PNG_MAN_DIR)
    set(PNG_MAN_DIR ${INSTALL_MAN_DIR})
  endif()
  install(FILES libpng.3 libpngpf.3      DESTINATION ${PNG_MAN_DIR}/man3)
  install(FILES png.5                    DESTINATION ${PNG_MAN_DIR}/man5)
  # Install pkg-config files
  if(NOT WIN32 OR CYGWIN OR MINGW)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libpng.pc
            DESTINATION ${INSTALL_LIB_DIR}/pkgconfig)
    install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/libpng-config
            DESTINATION ${INSTALL_BIN_DIR})
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PNGLIB_NAME}.pc
            DESTINATION ${INSTALL_LIB_DIR}/pkgconfig)
    install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/${PNGLIB_NAME}-config
            DESTINATION ${INSTALL_BIN_DIR})
  endif(NOT WIN32 OR CYGWIN OR MINGW)
endif()

# On versions of CMake that support it, create an export file CMake
# users can include() to import our targets
if(PNG_EXPORT_RULE AND NOT SKIP_INSTALL_EXPORT AND NOT SKIP_INSTALL_ALL )
  install(EXPORT libpng DESTINATION ${INSTALL_LIB_DIR}/libpng FILE lib${PNG_LIB_NAME}.cmake)
endif()

# what's with libpng-manual.txt and all the extra files?

# UNINSTALL
# do we need this?
add_custom_target(uninstall COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)

# DIST
# do we need this?

# to create msvc import lib for mingw compiled shared lib
# pexports libpng.dll > libpng.def
# lib /def:libpng.def /machine:x86

