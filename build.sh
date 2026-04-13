#!/bin/bash

set -euo pipefail

# Silence Qt 6 commercial "qtframework" license prompts during moc/rcc and at runtime
# when using a Qt installation that expects Qt License Service (set to 0 to enforce checks).
export QTFRAMEWORK_BYPASS_LICENSE_CHECK="${QTFRAMEWORK_BYPASS_LICENSE_CHECK:-1}"

MODE=${MODE:-Debug}
C=${C:-/usr/bin/gcc}
CXX=${CXX:-/usr/bin/g++}
# Qt 6 prefix: directory that contains lib/cmake/Qt6 (same as CMAKE_PREFIX_PATH).
QT_LIBS="${CMAKE_PREFIX_PATH:-${QT_LIBS:-}}"
if [[ -z "${QT_LIBS}" ]]; then
  echo "Set CMAKE_PREFIX_PATH or QT_LIBS to your Qt 6 install prefix, e.g. /path/to/Qt/6.10.0/gcc_64" >&2
  exit 1
fi
SOURCE=.
DESTINATION=${DESTINATION:-./build}

# Clean up
rm -rf "$DESTINATION"
mkdir -p "$DESTINATION"

# Configure
cmake \
  -DCMAKE_BUILD_TYPE:STRING=$MODE \
  -DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=TRUE \
  -DCMAKE_C_COMPILER:FILEPATH=$C \
  -DCMAKE_CXX_COMPILER:FILEPATH=$CXX \
  -DCMAKE_PREFIX_PATH:PATH="$QT_LIBS" \
  --no-warn-unused-cli \
  -S$SOURCE \
  -B$DESTINATION \
  -G Ninja

# Build
cmake --build "$DESTINATION"

# Test
ctest --test-dir "$DESTINATION" --output-on-failure

# Start app
"$DESTINATION/poker/Poker"
