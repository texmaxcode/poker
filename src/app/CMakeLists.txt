set(PROJECT_SOURCES
        main.cpp
        mainwindow.cpp
        mainwindow.h
        mainwindow.ui
)

add_executable(Trader ${PROJECT_SOURCES})

target_link_libraries(Trader PRIVATE 
    image_reader
    Qt6::Widgets
)

set_target_properties(Trader PROPERTIES
    WIN32_EXECUTABLE ON 
)