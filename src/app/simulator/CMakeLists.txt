cmake_minimum_required(VERSION 3.26)

project(simulator VERSION 0.0.1)

set(PROJECT_TYPE STATIC)

find_package(SqliteOrm REQUIRED)
find_package(Boost COMPONENTS system filesystem log_setup log unit_test_framework REQUIRED)
include_directories(${TEST_SOURCE_DIR}/src ${Boost_INCLUDE_DIRS})
add_definitions(-DBOOST_TEST_DYN_LINK)


set(code
  simulator.cpp
  storage.cpp
)

add_subdirectory(tests)

include_directories(include)
qt_add_library(simulator ${PROJECT_TYPE} ${code})

target_link_libraries(simulator PRIVATE
    sqlite_orm::sqlite_orm
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::Gui
    Qt${QT_VERSION_MAJOR}::Quick
    Qt${QT_VERSION_MAJOR}::Qml
)
target_include_directories(simulator INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
