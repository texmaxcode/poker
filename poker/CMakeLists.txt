cmake_minimum_required(VERSION 3.26)

add_executable(Poker
    main.cpp
    qml/application.qrc
)

set_target_properties(Poker PROPERTIES
    WIN32_EXECUTABLE ON 
)

add_subdirectory(poker)

target_link_libraries(Poker
    PRIVATE poker
    PRIVATE Qt${QT_VERSION_MAJOR}::Core
    PRIVATE Qt${QT_VERSION_MAJOR}::Gui
    PRIVATE Qt${QT_VERSION_MAJOR}::Quick
    PRIVATE Qt${QT_VERSION_MAJOR}::Qml
)

if(UNIX AND NOT APPLE)
    include(GNUInstallDirs)
    install(TARGETS Poker RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/qml/assets/images/logo.png"
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/512x512/apps"
        RENAME texas-holdem-gym.png)
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/packaging/linux/texas-holdem-gym.desktop"
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")

    add_custom_target(install-local
        COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/packaging/linux/install-local.sh"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        COMMENT "Self-contained install to $ENV{HOME}/poker-gym (+ optional ~/bin link)"
    )
    add_custom_target(install-rootfs
        COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/packaging/linux/install-rootfs.sh"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        COMMENT "Stage FHS tree under build/rootfs (usr/bin, usr/lib/poker-gym, usr/share)"
    )
endif()

if(MSVC)
    target_compile_options(Poker PRIVATE /W4 /permissive-)
else()
    target_compile_options(Poker PRIVATE -Wall -Wextra -Wpedantic)
endif()
