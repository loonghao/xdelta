cmake_minimum_required(VERSION 3.14)
project(test_xdelta_config)

# Find xdelta package
find_package(xdelta CONFIG REQUIRED)

# Create a simple test executable
add_executable(test_xdelta test_xdelta.cpp)

# Link with xdelta
target_link_libraries(test_xdelta PRIVATE xdelta::xdelta)

# Print some information
message(STATUS "xdelta found: ${xdelta_FOUND}")
if(TARGET xdelta::xdelta)
    message(STATUS "xdelta::xdelta target is available")
    get_target_property(XDELTA_INCLUDE_DIRS xdelta::xdelta INTERFACE_INCLUDE_DIRECTORIES)
    get_target_property(XDELTA_LOCATION xdelta::xdelta IMPORTED_LOCATION)
    message(STATUS "xdelta include dirs: ${XDELTA_INCLUDE_DIRS}")
    message(STATUS "xdelta library: ${XDELTA_LOCATION}")
endif()
