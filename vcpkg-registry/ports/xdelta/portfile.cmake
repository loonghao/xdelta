# Build xdelta from source
vcpkg_from_git(
    OUT_SOURCE_PATH SOURCE_PATH
    URL https://github.com/loonghao/xdelta.git
    REF release3_1_apl
    HEAD_REF release3_1_apl
)

# Configure CMake
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DXDELTA_ENABLE_LZMA=ON
        -DXDELTA_BUILD_TESTS=OFF
        -DXDELTA_BUILD_SHARED_LIBS=OFF
)

# Build the project
vcpkg_cmake_build()

# Install the project
vcpkg_cmake_install()

# Install include files
file(INSTALL "${SOURCE_PATH}/xdelta3/xdelta3.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include/xdelta3")
file(INSTALL "${SOURCE_PATH}/xdelta3/xdelta3-decode.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include/xdelta3")
file(INSTALL "${SOURCE_PATH}/xdelta3/xdelta3-list.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include/xdelta3")
file(INSTALL "${SOURCE_PATH}/xdelta3/xdelta3-main.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include/xdelta3")

# Handle copyright
file(INSTALL "${SOURCE_PATH}/COPYING" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

# Generate CMake configuration files
include(CMakePackageConfigHelpers)

# Configure the config file from template
configure_package_config_file(
    "${CMAKE_CURRENT_LIST_DIR}/xdeltaConfig.cmake.in"
    "${CURRENT_PACKAGES_DIR}/share/${PORT}/xdeltaConfig.cmake"
    INSTALL_DESTINATION "share/${PORT}"
    PATH_VARS CMAKE_INSTALL_INCLUDEDIR CMAKE_INSTALL_LIBDIR
)

# Generate version file
write_basic_package_version_file(
    "${CURRENT_PACKAGES_DIR}/share/${PORT}/xdeltaConfigVersion.cmake"
    VERSION ${VERSION}
    COMPATIBILITY SameMajorVersion
)

# Configure usage
configure_file("${CMAKE_CURRENT_LIST_DIR}/usage" "${CURRENT_PACKAGES_DIR}/share/${PORT}/usage" COPYONLY)

