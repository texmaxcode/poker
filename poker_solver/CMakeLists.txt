add_executable(PokerSolver
    main.cpp
)

set_target_properties(PokerSolver PROPERTIES
    WIN32_EXECUTABLE ON 
)

qt_add_qml_module(PokerSolver
    URI SolverUI
    VERSION 0.1
    QML_FILES
        qml/Main.qml
        qml/Dashboard.qml
        qml/About.qml
    RESOURCES
        qml/assets/images/poker_table.jpg
)

add_subdirectory(simulator)
add_subdirectory(poker)

target_link_libraries(PokerSolver PRIVATE
    simulator
    poker
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::Gui
    Qt${QT_VERSION_MAJOR}::Quick
    Qt${QT_VERSION_MAJOR}::Qml
)
