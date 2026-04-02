cmake_minimum_required(VERSION 3.26)

add_executable(Poker
    main.cpp
    qml/application.qrc
)

set_target_properties(Poker PROPERTIES
    WIN32_EXECUTABLE ON 
)

add_subdirectory(poker)

target_link_libraries(Poker
    PRIVATE poker
    PRIVATE Qt${QT_VERSION_MAJOR}::Core
    PRIVATE Qt${QT_VERSION_MAJOR}::Gui
    PRIVATE Qt${QT_VERSION_MAJOR}::Quick
    PRIVATE Qt${QT_VERSION_MAJOR}::Qml
)

if(MSVC)
    target_compile_options(Poker PRIVATE /W4 /permissive-)
else()
    target_compile_options(Poker PRIVATE -Wall -Wextra -Wpedantic)
endif()
