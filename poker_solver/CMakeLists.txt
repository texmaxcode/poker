cmake_minimum_required(VERSION 3.26)

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
        qml/PlayerSpot.qml
        qml/Table.qml
        qml/Card.qml
    RESOURCES
        qml/assets/images/poker_table.jpg
        # Cards backs
        qml/assets/cards_svgs/blue2.svg
        qml/assets/cards_svgs/red2.svg
        # Cards fronts
        qml/assets/cards_svgs/clubs_ace.svg
        qml/assets/cards_svgs/clubs_king.svg
        qml/assets/cards_svgs/clubs_queen.svg
        qml/assets/cards_svgs/clubs_jack.svg
        qml/assets/cards_svgs/clubs_10.svg
        qml/assets/cards_svgs/clubs_9.svg
        qml/assets/cards_svgs/clubs_8.svg
        qml/assets/cards_svgs/clubs_7.svg
        qml/assets/cards_svgs/clubs_6.svg
        qml/assets/cards_svgs/clubs_5.svg
        qml/assets/cards_svgs/clubs_4.svg
        qml/assets/cards_svgs/clubs_3.svg
        qml/assets/cards_svgs/clubs_2.svg

        qml/assets/cards_svgs/spades_ace.svg
        qml/assets/cards_svgs/spades_king.svg
        qml/assets/cards_svgs/spades_queen.svg
        qml/assets/cards_svgs/spades_jack.svg
        qml/assets/cards_svgs/spades_10.svg
        qml/assets/cards_svgs/spades_9.svg
        qml/assets/cards_svgs/spades_8.svg
        qml/assets/cards_svgs/spades_7.svg
        qml/assets/cards_svgs/spades_6.svg
        qml/assets/cards_svgs/spades_5.svg
        qml/assets/cards_svgs/spades_4.svg
        qml/assets/cards_svgs/spades_3.svg
        qml/assets/cards_svgs/spades_2.svg

        qml/assets/cards_svgs/diamonds_ace.svg
        qml/assets/cards_svgs/diamonds_king.svg
        qml/assets/cards_svgs/diamonds_queen.svg
        qml/assets/cards_svgs/diamonds_jack.svg
        qml/assets/cards_svgs/diamonds_10.svg
        qml/assets/cards_svgs/diamonds_9.svg
        qml/assets/cards_svgs/diamonds_8.svg
        qml/assets/cards_svgs/diamonds_7.svg
        qml/assets/cards_svgs/diamonds_6.svg
        qml/assets/cards_svgs/diamonds_5.svg
        qml/assets/cards_svgs/diamonds_4.svg
        qml/assets/cards_svgs/diamonds_3.svg
        qml/assets/cards_svgs/diamonds_2.svg

        qml/assets/cards_svgs/hearts_ace.svg
        qml/assets/cards_svgs/hearts_king.svg
        qml/assets/cards_svgs/hearts_queen.svg
        qml/assets/cards_svgs/hearts_jack.svg
        qml/assets/cards_svgs/hearts_10.svg
        qml/assets/cards_svgs/hearts_9.svg
        qml/assets/cards_svgs/hearts_8.svg
        qml/assets/cards_svgs/hearts_7.svg
        qml/assets/cards_svgs/hearts_6.svg
        qml/assets/cards_svgs/hearts_5.svg
        qml/assets/cards_svgs/hearts_4.svg
        qml/assets/cards_svgs/hearts_3.svg
        qml/assets/cards_svgs/hearts_2.svg
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
