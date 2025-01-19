cmake_minimum_required(VERSION 3.16)

project(Trader VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)
qt_standard_project_setup()

add_subdirectory(src/app)
add_subdirectory(src/image_reader)
