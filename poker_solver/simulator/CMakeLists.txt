cmake_minimum_required(VERSION 3.26)

find_package(SqliteOrm REQUIRED)
find_package(Boost COMPONENTS system filesystem log_setup log unit_test_framework REQUIRED)
include_directories(${TEST_SOURCE_DIR}/src ${Boost_INCLUDE_DIRS})
add_definitions(-DBOOST_TEST_DYN_LINK)

add_subdirectory(tests)

qt_add_library(simulator
  storage.cpp
  simulator.cpp
)

target_link_libraries(simulator
    INTERFACE sqlite_orm::sqlite_orm
    PRIVATE Qt${QT_VERSION_MAJOR}::Core
    PRIVATE Qt${QT_VERSION_MAJOR}::Gui
    PRIVATE Qt${QT_VERSION_MAJOR}::Quick
    PRIVATE Qt${QT_VERSION_MAJOR}::Qml
)
target_include_directories(simulator INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
