cmake_minimum_required(VERSION 3.26)

project(PokerSolver VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick)

qt_standard_project_setup()

add_subdirectory(app)
