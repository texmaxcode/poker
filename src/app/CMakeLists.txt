set(PROJECT_SOURCES
        main.cpp
)

add_executable(Trader ${PROJECT_SOURCES})

set_target_properties(Trader PROPERTIES
    WIN32_EXECUTABLE ON 
)

qt_add_qml_module(Trader
    URI com.musclecomputing.UI 
    VERSION 1.0
    QML_FILES
        Main.qml
)

target_link_libraries(Trader PRIVATE 
    image_reader
    Qt6::Quick
)
