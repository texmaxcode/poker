#!/bin/bash

MODE=Debug
C=/usr/bin/gcc
CXX=/usr/bin/g++
QT_LIBS=/home/max-gloom/Qt/6.8.1/gcc_64
SOURCE=.
DESTINATION=./build

rm -rf build && mkdir build && rm poker_simulator.data;

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

cd build && ninja && cd ..

./build/src/app/simulator/tests/Test -l all -r short

./build/src/app/PokerSolver
