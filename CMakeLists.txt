cmake_minimum_required(VERSION 3.26)

# So `cmake -DBUILD_TESTING=OFF` is honored when include(CTest) defines the BUILD_TESTING option (CI / release builds).
if(POLICY CMP0077)
  cmake_policy(SET CMP0077 NEW)
endif()

# Qt commercial installer: silence "qtframework" license service prompts for moc/uic/rcc (set to 0 to enforce).
if(NOT DEFINED ENV{QTFRAMEWORK_BYPASS_LICENSE_CHECK})
    set(ENV{QTFRAMEWORK_BYPASS_LICENSE_CHECK} "1")
endif()

project(Poker VERSION 0.1 LANGUAGES CXX)

include("${CMAKE_SOURCE_DIR}/cmake/GitVersion.cmake")

file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/generated")
configure_file(
    "${CMAKE_SOURCE_DIR}/cmake/version.h.in"
    "${CMAKE_BINARY_DIR}/generated/poker_version.h"
    @ONLY
)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN YES)

option(BUILD_SHARED_LIBS "Build shared libraries?" NO)

find_package(Qt6 6.10 REQUIRED COMPONENTS Core Gui Qml Quick Network)
# Persistence uses the system SQLite3 C API (not Qt SQL plugins), so it works with bundled installs
# and arbitrary `QT_PLUGIN_PATH` without `sqldrivers`.
find_package(SQLite3 REQUIRED)

if(QT_KNOWN_POLICY_QTP0003)
    qt_policy(SET QTP0003 NEW)
endif()

qt_standard_project_setup()

include(CTest)
enable_testing()

add_subdirectory(poker)
