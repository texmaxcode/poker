cmake_minimum_required(VERSION 3.26)

project(PokerSolver VERSION 0.1 LANGUAGES CXX)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick)

qt_standard_project_setup()

add_subdirectory(src/app)
add_subdirectory(src/image_reader)
