add_executable(Test_poker test.cpp)

target_link_libraries(Test_poker
    poker 
    ${Boost_UNIT_TEST_FRAMEWORK_LIBRARY}
)
