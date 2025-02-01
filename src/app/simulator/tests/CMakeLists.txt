add_executable(Test_simulator test.cpp)

target_link_libraries(Test_simulator
    simulator
    ${Boost_UNIT_TEST_FRAMEWORK_LIBRARY}
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::Gui
    Qt${QT_VERSION_MAJOR}::Quick
    Qt${QT_VERSION_MAJOR}::Qml
)
