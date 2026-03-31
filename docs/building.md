# Building Poker

## Configure Qt

CMake must be able to find `Qt6Config.cmake`. You can do that by setting one of:

- `CMAKE_PREFIX_PATH` to your Qt install prefix (commonly ends with `.../Qt/6.x.y/<compiler_triplet>`)
- `Qt6_DIR` to the directory containing `Qt6Config.cmake`

Example:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH="$HOME/Qt/6.10.0/gcc_64"
```

## Build

```bash
cmake --build build -j
```

## Test

```bash
ctest --test-dir build --output-on-failure
```

## Troubleshooting

### “Could not find a package configuration file provided by Qt6”

Install Qt6 development packages, or set `CMAKE_PREFIX_PATH` / `Qt6_DIR` as described above.

### Boost unit tests

The unit tests use Boost’s `unit_test_framework`. If CMake can’t find it, install Boost dev packages for your distro or point CMake at your Boost install.

