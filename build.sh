#!/bin/bash

set -euo pipefail

MODE=${MODE:-Debug}
C=${C:-/usr/bin/gcc}
CXX=${CXX:-/usr/bin/g++}
QT_LIBS=${QT_LIBS:-/home/max-gloom/Qt/6.10.0/gcc_64}
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
  -DCMAKE_PREFIX_PATH:PATH=$QT_LIBS \
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
