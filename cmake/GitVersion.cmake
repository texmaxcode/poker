# Resolves POKER_GIT_HASH (short) and POKER_APP_VERSION ("<project>+<hash>").
# Override: -DPOKER_GIT_HASH_OVERRIDE=abc12345 or env POKER_GIT_HASH (e.g. CI).

set(POKER_GIT_HASH "")
if(DEFINED POKER_GIT_HASH_OVERRIDE AND NOT POKER_GIT_HASH_OVERRIDE STREQUAL "")
    set(POKER_GIT_HASH "${POKER_GIT_HASH_OVERRIDE}")
elseif(DEFINED ENV{POKER_GIT_HASH} AND NOT "$ENV{POKER_GIT_HASH}" STREQUAL "")
    set(POKER_GIT_HASH "$ENV{POKER_GIT_HASH}")
else()
    find_program(POKER_GIT_EXECUTABLE NAMES git NO_CMAKE_PATH)
    if(POKER_GIT_EXECUTABLE AND EXISTS "${CMAKE_SOURCE_DIR}/.git")
        execute_process(
            COMMAND "${POKER_GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" rev-parse --short=8 HEAD
            OUTPUT_VARIABLE POKER_GIT_HASH
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
            RESULT_VARIABLE _poker_git_ec
        )
        if(NOT _poker_git_ec EQUAL 0)
            set(POKER_GIT_HASH "")
        endif()
    endif()
endif()

if(POKER_GIT_HASH STREQUAL "")
    set(POKER_GIT_HASH "unknown")
else()
    string(LENGTH "${POKER_GIT_HASH}" _poker_gh_len)
    if(_poker_gh_len GREATER 8)
        string(SUBSTRING "${POKER_GIT_HASH}" 0 8 POKER_GIT_HASH)
    endif()
endif()

set(POKER_APP_VERSION "${PROJECT_VERSION}+${POKER_GIT_HASH}")
message(STATUS "Poker version: ${POKER_APP_VERSION}")
