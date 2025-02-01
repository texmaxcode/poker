cmake_minimum_required(VERSION 3.26)

project(poker VERSION 0.0.1)

set(PROJECT_TYPE STATIC)

find_package(Boost COMPONENTS system filesystem log_setup log unit_test_framework REQUIRED)
include_directories(${TEST_SOURCE_DIR}/src ${Boost_INCLUDE_DIRS})
add_definitions(-DBOOST_TEST_DYN_LINK)

set(code
  cards.cpp
  utils.hpp
)

add_subdirectory(tests)

include_directories(include)
add_library(poker ${PROJECT_TYPE} ${code})

target_link_libraries(poker PRIVATE
    Qt${QT_VERSION_MAJOR}::Qml
)
target_include_directories(poker INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
