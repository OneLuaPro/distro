# MIT License
#
# Copyright (c) 2025-2026 Kritzel Kratzel.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in 
# the Software without restriction, including without limitation the rights to 
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all 
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# ------------------------------------------------------------------------------
# CMake for distro
# ------------------------------------------------------------------------------
# Setup with Visual Studio 17 2022 generator for x64
# ------------------------------------------------------------------------------
# Visual Studio is a mutlti-configuration generator
# https://stackoverflow.com/questions/24460486/
#
# Basic instructions for out-of-source build
# ------------------------------------------
# mkdir build && cd build
# cmake .. -G "Visual Studio 17 2022" -A x64
# cmake --build . --config Release
# cmake --install . --config Release
# 
# Available architectures (-A ...) are: Win32, x64, ARM, ARM64

# ------------------------------------------------------------------------------
# General definitions
cmake_minimum_required(VERSION 3.23 FATAL_ERROR)

# ------------------------------------------------------------------------------
# find liblua installation and version info
if(NOT LUA_HINTS)
  if(WIN32)
    set(LUA_HINTS "c:/Apps")
  endif()
endif()
find_package(liblua REQUIRED CONFIG HINTS ${LUA_HINTS})
if(liblua_FOUND)
  message(STATUS "liblua version        : ${liblua_VERSION}")
  message(STATUS "liblua install prefix : ${LIBLUA_INSTALLDIR}")
  message(STATUS "liblua include dir    : ${LIBLUA_INCLUDEDIR}")
  message(STATUS "liblua lib dir        : ${LIBLUA_LIBDIR}")
else()
  message(FATAL_ERROR "Unable to find liblua version ${liblua_VERSION}.")
endif()
# Note: liblua_VERSION is set by find_package() directly. LIBLUA_INSTALLDIR,
# LIBLUA_INCLUDEDIR and LIBLUA_LIBDIR are set by libluaConfigVersion.cmake in
# <prefix>/share/cmake/liblua.

# ------------------------------------------------------------------------------
# Installation prefix directory - automatically set from find_package()
# Needs to be defined before project definition statement - for whatever reason
if(NOT CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX ${LIBLUA_INSTALLDIR})
endif()

# ------------------------------------------------------------------------------
# Project defintion
project(distro C CXX)

# ------------------------------------------------------------------------------
# Other settings
set(CMAKE_VERBOSE_MAKEFILE ON)
if(NOT CMAKE_BUILD_TYPE)
  # Visual Studio generators irgore this setting
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()
# create valiable with upper-case content out of CMAKE_BUILD_TYPE
string(TOUPPER ${CMAKE_BUILD_TYPE} CMAKE_BUILD_TYPE_UC)

# ------------------------------------------------------------------------------
# Setup GNU-alike installatin directories
include (GNUInstallDirs)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/${CMAKE_INSTALL_BINDIR})
set(INSTALL_LIBDIR
  ${CMAKE_INSTALL_LIBDIR} CACHE PATH "Installation directory for libraries")
set(INSTALL_BINDIR
  ${CMAKE_INSTALL_BINDIR} CACHE PATH "Installation directory for executables")
set(INSTALL_INCLUDEDIR
  ${CMAKE_INSTALL_INCLUDEDIR} CACHE PATH "Installation directory for header files")
set(INSTALL_DOCDIR
  ${CMAKE_INSTALL_DOCDIR} CACHE PATH "Installation directory for documentation")
set(INSTALL_MANDIR
  ${CMAKE_INSTALL_MANDIR} CACHE PATH "Installation directory for manpages")
set(INSTALL_DATAROOTDIR
  ${CMAKE_INSTALL_DATAROOTDIR} CACHE PATH "Installation directory for data")
# Lua-specific installation dirs
set(INSTALL_TOP_CDIR
  ${INSTALL_LIBDIR}/lua/${liblua_VERSION_MAJOR}.${liblua_VERSION_MINOR})
set(INSTALL_TOP_LDIR
  ${INSTALL_DATAROOTDIR}/lua/${liblua_VERSION_MAJOR}.${liblua_VERSION_MINOR})
# OneLuaPro-specific installation dirs
set(INSTALL_APPDIR
  "opt/DistroCheck" CACHE PATH "Installation directory for app")

# ------------------------------------------------------------------------------
# Report to user
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C compiler flags: ${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE_UC}}")

# ------------------------------------------------------------------------------
# configure lua module
IF(NOT ONELUAPRO_VERSION)  
  message(FATAL_ERROR "Variable ONELUAPRO_VERSION is not set - cannot continue.")
ENDIF()
# Check if we have a release candidate suffix from command-line variable
string(LENGTH "${ONELUAPRO_CANDIDATE}" suffix_len)
IF(suffix_len GREATER 0)
  message(STATUS "Using release candidate suffix ${ONELUAPRO_CANDIDATE}.")
  set(ONELUAPRO_VERSION "${ONELUAPRO_VERSION}${ONELUAPRO_CANDIDATE}")
  message(STATUS "Release string is: ${ONELUAPRO_VERSION}")
ENDIF()
configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/distro.lua.in
  ${CMAKE_CURRENT_BINARY_DIR}/distro.lua
)

# ------------------------------------------------------------------------------
# distro core DLL
add_library(core SHARED)
# setup lua include directory
target_include_directories(core PRIVATE ${LIBLUA_INCLUDEDIR})
# plattform-independend sources
target_sources(core PRIVATE core.c)
# setup platform-specific sources, compile and linker options
if(WIN32 AND NOT MinGW)
  # Important definitions for DLL and symbol export
  target_compile_definitions(core PRIVATE
    LUA_BUILD_AS_DLL LUA_LIB
    _WINDLL _WIN32 _CRT_SECURE_NO_WARNINGS
  )
  # set deviating library output name
  set_target_properties(core PROPERTIES PREFIX "")
  set_target_properties(core PROPERTIES OUTPUT_NAME core)
  # We silently assume all libs are available with headers and static lib
  target_link_directories(core PRIVATE ${LIBLUA_LIBDIR})
  target_link_libraries(core PRIVATE liblua wintrust)
else()
  message(FATAL_ERROR "Not yet fully implemented.")
endif()
# Install
install(TARGETS core RUNTIME DESTINATION ${INSTALL_TOP_CDIR}/distro)

# ------------------------------------------------------------------------------
# DistroCheck Launcher (.exe instead of .bat)
if(WIN32)
  # Create the target (WIN32 flag prevents the console window from appearing)
  add_executable(DistroCheckLauncher WIN32
    DistroCheck/assets/lua-logo-olp-dist.rc
    DistroCheck.cpp)

  target_include_directories(DistroCheckLauncher PRIVATE ${LIBLUA_INCLUDEDIR})
  target_link_directories(DistroCheckLauncher PRIVATE ${LIBLUA_LIBDIR})
  target_link_libraries(DistroCheckLauncher PRIVATE liblua.lib pathcch.lib)
  set_target_properties(DistroCheckLauncher PROPERTIES OUTPUT_NAME "DistroCheck")

  install(TARGETS DistroCheckLauncher RUNTIME DESTINATION ${INSTALL_APPDIR})
endif()


# ------------------------------------------------------------------------------
# Install 
install(
  FILES ${CMAKE_CURRENT_BINARY_DIR}/distro.lua
  DESTINATION ${INSTALL_TOP_LDIR}
)
install(FILES
  README.html
  DESTINATION ${INSTALL_DOCDIR}
)
install(DIRECTORY
  assets
  DESTINATION ${INSTALL_DOCDIR}
  FILES_MATCHING
  PATTERN "*.png"
)
install(DIRECTORY
  DistroCheck
  DESTINATION ${INSTALL_APPDIR}
  FILES_MATCHING
  PATTERN "*.lua"
  PATTERN "*.txt"
  PATTERN "*.ico"
)
install(FILES
  DistroCheck.lua
  DistroCheck.bat
  DESTINATION ${INSTALL_APPDIR}
)
