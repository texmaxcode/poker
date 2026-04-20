cmake_minimum_required(VERSION 3.26)

if(BUILD_TESTING)
    find_package(Boost 1.70 REQUIRED COMPONENTS unit_test_framework)
    add_subdirectory(tests)
endif()

qt_add_library(poker
  cards.cpp
  player.cpp
  holdem_side_pot.cpp
  bankroll_tracker.cpp
  game.cpp
  game_payouts.cpp
  game_persistence.cpp
  seat_manager.cpp
  human_decision_controller.cpp
  game_ui_sync.cpp
  hand_eval.cpp
  range_matrix.cpp
  bot.cpp
  equity_engine.cpp
  poker_solver.cpp
  toy_nash_solver.cpp
  training_store.cpp
  training_controller.cpp
  session_store.cpp
  persist_sqlite.cpp
  hand_log_store.cpp
  hand_history_query.cpp
)

target_link_libraries(poker PRIVATE
  Qt${QT_VERSION_MAJOR}::Core
  Qt${QT_VERSION_MAJOR}::Qml
  SQLite::SQLite3
)
target_include_directories(poker INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})

target_compile_features(poker PUBLIC cxx_std_17)

if(MSVC)
    target_compile_options(poker PRIVATE /W4 /permissive-)
else()
    target_compile_options(poker PRIVATE -Wall -Wextra -Wpedantic)
endif()
