# PNGTest.cmake
# Utility functions for testing libpng

# Copyright (c) 2018-2025 Cosmin Truta
# Copyright (c) 2016-2018 Glenn Randers-Pehrson
# Written by Roger Leigh, 2016
#
# Use, modification and distribution are subject to
# the same licensing terms and conditions as libpng.
# Please see the copyright notice in png.h or visit
# http://libpng.org/pub/png/src/libpng-LICENSE.txt
#
# SPDX-License-Identifier: libpng-2.0

# Add a custom target to run a test:
# png_add_test(NAME <test> COMMAND <command> [OPTIONS <options>...] [FILES <files>...])
function(png_add_test)
  set(options)
  set(oneValueArgs NAME COMMAND)
  set(multiValueArgs OPTIONS FILES)
  cmake_parse_arguments(_PAT "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  if(NOT _PAT_NAME)
    message(FATAL_ERROR "png_add_test: Missing NAME argument")
  endif()
  if(NOT _PAT_COMMAND)
    message(FATAL_ERROR "png_add_test: Missing COMMAND argument")
  endif()

  # Initialize the global variables used by the "${_PAT_NAME}.cmake" script.
  set(TEST_OPTIONS "${_PAT_OPTIONS}")
  set(TEST_FILES "${_PAT_FILES}")
  set(TEST_PATH_DIRS "")

  if(WIN32)
    # Ensure test executables can resolve dependent DLLs (e.g. zlib) on CI.
    list(APPEND TEST_PATH_DIRS
         "$<TARGET_FILE_DIR:${_PAT_COMMAND}>"
         "$<TARGET_FILE_DIR:png_shared>")

    if(TARGET ZLIB::ZLIB)
      list(APPEND TEST_PATH_DIRS "$<TARGET_FILE_DIR:ZLIB::ZLIB>")
    elseif(DEFINED ZLIB_LIBRARY AND NOT ZLIB_LIBRARY STREQUAL "")
      get_filename_component(_ZLIB_LIBRARY_DIR "${ZLIB_LIBRARY}" DIRECTORY)
      list(APPEND TEST_PATH_DIRS "${_ZLIB_LIBRARY_DIR}")
      get_filename_component(_ZLIB_ROOT_DIR "${_ZLIB_LIBRARY_DIR}" DIRECTORY)
      if(EXISTS "${_ZLIB_ROOT_DIR}/bin")
        list(APPEND TEST_PATH_DIRS "${_ZLIB_ROOT_DIR}/bin")
      endif()
    endif()
  endif()

  # Generate and run the "${_PAT_NAME}.cmake" script.
  configure_file("${CMAKE_CURRENT_SOURCE_DIR}/scripts/cmake/test.cmake.in"
                 "${CMAKE_CURRENT_BINARY_DIR}/tests/${_PAT_NAME}.cmake"
                 @ONLY)
  add_test(NAME "${_PAT_NAME}"
           COMMAND "${CMAKE_COMMAND}"
                   "-DLIBPNG=$<TARGET_FILE:png_shared>"
                   "-DTEST_COMMAND=$<TARGET_FILE:${_PAT_COMMAND}>"
                   "-DTEST_PATH_DIRS=${TEST_PATH_DIRS}"
                   -P "${CMAKE_CURRENT_BINARY_DIR}/tests/${_PAT_NAME}.cmake")
endfunction()
