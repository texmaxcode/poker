cmake_minimum_required(VERSION 3.26)

add_executable(Poker
    main.cpp
    qml/application.qrc
)

target_include_directories(Poker PRIVATE "${CMAKE_BINARY_DIR}/generated")

set_target_properties(Poker PROPERTIES
    WIN32_EXECUTABLE ON
)

# macOS: .app bundle required for macdeployqt and Gatekeeper-friendly distribution
if(APPLE)
    set_target_properties(Poker PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "Texas Hold'em Gym"
        MACOSX_BUNDLE_GUI_IDENTIFIER com.texasholdemgym.poker
        MACOSX_BUNDLE_INFO_STRING "Texas Hold'em Gym"
        MACOSX_BUNDLE_LONG_VERSION_STRING "${POKER_APP_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_BUNDLE_VERSION "${POKER_GIT_HASH}"
    )
endif()

add_subdirectory(poker)

target_link_libraries(Poker
    PRIVATE poker
    PRIVATE Qt${QT_VERSION_MAJOR}::Core
    PRIVATE Qt${QT_VERSION_MAJOR}::Gui
    PRIVATE Qt${QT_VERSION_MAJOR}::Quick
    PRIVATE Qt${QT_VERSION_MAJOR}::Qml
    PRIVATE Qt${QT_VERSION_MAJOR}::Network
)

if(UNIX AND NOT APPLE)
    include(GNUInstallDirs)
    install(TARGETS Poker RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/qml/assets/images/logo.png"
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/512x512/apps"
        RENAME texas-holdem-gym.png)
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/packaging/linux/texas-holdem-gym.desktop"
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/packaging/linux/io.github.texasholdemgym.metainfo.xml.in"
        "${CMAKE_CURRENT_BINARY_DIR}/io.github.texasholdemgym.metainfo.xml"
        @ONLY
    )
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/io.github.texasholdemgym.metainfo.xml"
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/metainfo")

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
