find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

qt_add_library(image_reader STATIC
    image_reader.cpp
)
target_link_libraries(image_reader PRIVATE ${OpenCV_LIBS}
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::Gui
    Qt${QT_VERSION_MAJOR}::Quick
    Qt${QT_VERSION_MAJOR}::Qml
)
target_include_directories(image_reader INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
