find_package( OpenCV REQUIRED )
include_directories( ${OpenCV_INCLUDE_DIRS} )

qt_add_library(image_reader STATIC
    image_reader.cpp
)
target_link_libraries(image_reader PRIVATE Qt6::Core ${OpenCV_LIBS})
target_include_directories(image_reader INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
