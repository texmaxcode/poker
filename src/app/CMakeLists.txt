set(PROJECT_SOURCES
        main.cpp
)

add_executable(${CMAKE_PROJECT_NAME} ${PROJECT_SOURCES})

set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES
    WIN32_EXECUTABLE ON 
)

qt_add_qml_module(${CMAKE_PROJECT_NAME}
    URI TraderUI
    VERSION 0.1
    QML_FILES
        qml/Main.qml
)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
    image_reader
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::Gui
    Qt${QT_VERSION_MAJOR}::Quick
    Qt${QT_VERSION_MAJOR}::Qml
)
