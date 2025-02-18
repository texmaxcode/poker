cmake_minimum_required(VERSION 3.26)

add_executable(PokerSolver
    main.cpp
    qml/application.qrc
)

set_target_properties(PokerSolver PROPERTIES
    WIN32_EXECUTABLE ON 
)

add_subdirectory(simulator)
add_subdirectory(poker)

target_link_libraries(PokerSolver
    PRIVATE simulator
    PRIVATE poker
    PRIVATE Qt${QT_VERSION_MAJOR}::Core
    PRIVATE Qt${QT_VERSION_MAJOR}::Gui
    PRIVATE Qt${QT_VERSION_MAJOR}::Quick
    PRIVATE Qt${QT_VERSION_MAJOR}::Qml
)
