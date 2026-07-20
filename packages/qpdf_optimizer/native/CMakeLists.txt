cmake_minimum_required(VERSION 3.22)

project(qpdf_optimizer LANGUAGES C CXX)

include(ExternalProject)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/output")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/output")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/output")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/output")

if(NOT DEFINED QPDF_OPTIMIZER_THIRD_PARTY_ROOT)
  message(FATAL_ERROR "QPDF_OPTIMIZER_THIRD_PARTY_ROOT must point to the package's pinned native dependencies.")
endif()

set(DEPS_DIR "${CMAKE_BINARY_DIR}/deps")
file(MAKE_DIRECTORY "${DEPS_DIR}/include")

if(WIN32)
  set(ZLIB_LIBRARY "${DEPS_DIR}/lib/zlibstatic.lib")
  set(JPEG_LIBRARY "${DEPS_DIR}/lib/jpeg-static.lib")
  set(QPDF_LIBRARY "${DEPS_DIR}/lib/qpdf.lib")
else()
  set(ZLIB_LIBRARY "${DEPS_DIR}/lib/libz.a")
  set(JPEG_LIBRARY "${DEPS_DIR}/lib/libjpeg.a")
  set(QPDF_LIBRARY "${DEPS_DIR}/lib/libqpdf.a")
endif()

set(COMMON_ARGS
  -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
  -DCMAKE_INSTALL_PREFIX=${DEPS_DIR}
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
)

# When building for Android, force PIC on all static libs so they can be
# linked into a shared library (.so). qpdf overrides POSITION_INDEPENDENT_CODE
# based on BUILD_STATIC_LIBS, so we must inject -fPIC via flags.
if(ANDROID)
  list(APPEND COMMON_ARGS
    -DCMAKE_C_FLAGS=-fPIC
    -DCMAKE_CXX_FLAGS=-fPIC
  )
endif()

if(DEFINED QPDF_OPTIMIZER_C_COMPILER)
  list(APPEND COMMON_ARGS -DCMAKE_C_COMPILER=${QPDF_OPTIMIZER_C_COMPILER})
elseif(DEFINED CMAKE_C_COMPILER)
  list(APPEND COMMON_ARGS -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER})
endif()
if(DEFINED QPDF_OPTIMIZER_CXX_COMPILER)
  list(APPEND COMMON_ARGS -DCMAKE_CXX_COMPILER=${QPDF_OPTIMIZER_CXX_COMPILER})
elseif(DEFINED CMAKE_CXX_COMPILER)
  list(APPEND COMMON_ARGS -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER})
endif()
if(DEFINED QPDF_OPTIMIZER_AR)
  list(APPEND COMMON_ARGS -DCMAKE_AR=${QPDF_OPTIMIZER_AR})
endif()
if(DEFINED CMAKE_MAKE_PROGRAM)
  list(APPEND COMMON_ARGS
    -DCMAKE_MAKE_PROGRAM:FILEPATH=${CMAKE_MAKE_PROGRAM}
  )
endif()
if(DEFINED QPDF_OPTIMIZER_SYSTEM_PROCESSOR)
  list(APPEND COMMON_ARGS
    -DCMAKE_SYSTEM_PROCESSOR=${QPDF_OPTIMIZER_SYSTEM_PROCESSOR}
    -DQPDF_OPTIMIZER_SYSTEM_PROCESSOR=${QPDF_OPTIMIZER_SYSTEM_PROCESSOR}
  )
endif()
if(DEFINED CMAKE_TOOLCHAIN_FILE)
  list(APPEND COMMON_ARGS -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})
endif()

# When cross-compiling (e.g. for Android), disable pkg-config so that
# ExternalProject sub-builds (zlib, libjpeg-turbo, qpdf) don't pick up
# the host system's libraries via pkg_check_modules. Without this, qpdf
# finds the host's libjpeg headers (e.g. /usr/include/jpeglib.h) which
# are invisible to the Android NDK cross-compiler, causing a build
# failure. Disabling pkg-config forces the CMake find_path/find_library
# fallback, which respects the pre-set LIBJPEG_H_PATH / ZLIB_H_PATH
# cache variables passed below.
if(ANDROID)
  # Disable pkg-config so ExternalProject sub-builds don't find the host
  # system's libraries (e.g. /usr/include/jpeglib.h) which are invisible to
  # the Android NDK cross-compiler. CMake's FindPkgConfig module uses
  # find_program(PkgConfig_EXECUTABLE ...) — the variable name is camelCase,
  # not PKG_CONFIG_EXECUTABLE. We set both for safety.
  list(APPEND COMMON_ARGS
    -DPkgConfig_EXECUTABLE=NOTFOUND
    -DPKG_CONFIG_EXECUTABLE=NOTFOUND
  )
endif()
if(DEFINED QPDF_OPTIMIZER_ANDROID_ABI)
  list(APPEND COMMON_ARGS
    -DANDROID_ABI=${QPDF_OPTIMIZER_ANDROID_ABI}
    -DANDROID_PLATFORM=android-${QPDF_OPTIMIZER_ANDROID_API}
    -DANDROID_STL=c++_static
  )
endif()

ExternalProject_Add(
  zlib_project
  SOURCE_DIR "${QPDF_OPTIMIZER_THIRD_PARTY_ROOT}/zlib"
  BINARY_DIR "${CMAKE_BINARY_DIR}/zlib"
  CMAKE_ARGS
    ${COMMON_ARGS}
    -DZLIB_BUILD_EXAMPLES=OFF
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --target zlibstatic --config Release
  BUILD_BYPRODUCTS "${ZLIB_LIBRARY}"
)

ExternalProject_Add(
  jpeg_project
  SOURCE_DIR "${QPDF_OPTIMIZER_THIRD_PARTY_ROOT}/libjpeg-turbo"
  BINARY_DIR "${CMAKE_BINARY_DIR}/libjpeg-turbo"
  CMAKE_ARGS
    ${COMMON_ARGS}
    -DENABLE_SHARED=OFF
    -DENABLE_STATIC=ON
    -DWITH_TURBOJPEG=OFF
    -DWITH_JAVA=OFF
    -DWITH_JPEG8=ON
    -DCMAKE_PROJECT_INCLUDE=${CMAKE_CURRENT_SOURCE_DIR}/cmake/set_processor.cmake
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --target jpeg-static --config Release
  BUILD_BYPRODUCTS "${JPEG_LIBRARY}"
)

ExternalProject_Add(
  qpdf_project
  SOURCE_DIR "${QPDF_OPTIMIZER_THIRD_PARTY_ROOT}/qpdf"
  BINARY_DIR "${CMAKE_BINARY_DIR}/qpdf"
  DEPENDS zlib_project jpeg_project
  CMAKE_ARGS
    ${COMMON_ARGS}
    -DBUILD_SHARED_LIBS=OFF
    -DBUILD_STATIC_LIBS=ON
    -DBUILD_DOC=OFF
    -DINSTALL_EXAMPLES=OFF
    -DINSTALL_MANUAL=OFF
    -DINSTALL_PKGCONFIG=OFF
    -DINSTALL_CMAKE_PACKAGE=OFF
    -DGENERATE_AUTO_JOB=OFF
    -DREQUIRE_CRYPTO_NATIVE=ON
    -DUSE_IMPLICIT_CRYPTO=OFF
    -DWERROR=OFF
    -DZLIB_H_PATH=${DEPS_DIR}/include
    -DZLIB_LIB_PATH=${ZLIB_LIBRARY}
    -DLIBJPEG_H_PATH=${DEPS_DIR}/include
    -DLIBJPEG_LIB_PATH=${JPEG_LIBRARY}
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --target libqpdf --config Release
  BUILD_BYPRODUCTS "${QPDF_LIBRARY}"
)

add_library(qpdf_static STATIC IMPORTED GLOBAL)
set_target_properties(qpdf_static PROPERTIES IMPORTED_LOCATION "${QPDF_LIBRARY}")

add_library(qpdf_optimizer SHARED qpdf_bridge.cpp)
add_dependencies(qpdf_optimizer qpdf_project)
target_include_directories(
  qpdf_optimizer
  PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
    "${DEPS_DIR}/include"
)
target_link_libraries(qpdf_optimizer PRIVATE qpdf_static "${JPEG_LIBRARY}" "${ZLIB_LIBRARY}")

if(WIN32)
  target_link_libraries(qpdf_optimizer PRIVATE advapi32 crypt32 ws2_32)
elseif(ANDROID)
  target_link_libraries(qpdf_optimizer PRIVATE android log)
endif()
