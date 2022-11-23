#!/bin/bash

set -e -x


while getopts "a:j:p:" arg; do
  case "$arg" in
  a)
    ARCH="$OPTARG"
    ;;
  j)
    NUM_JOBS="$OPTARG"
    ;;
  p)
    PLATFORM="$OPTARG"
    ;;
  *)
    ;;
  esac
done


CURRENT_DIR="$(pwd)"
SOURCE_DIR="$CURRENT_DIR"

mkdir -p tblgen_build
TABGEN_BUILDIR=$(pwd)/tblgen_build
#  TABGEN_BUILDIR=$(tmpdir)
pushd "$TABGEN_BUILDIR"

python3 -m pip install -r "$SOURCE_DIR/llvm-project/mlir/python/requirements.txt"
python3 -m pip uninstall -y pybind11
python3 -m pip install pybind11==2.10.1 cmake==3.24.0 -U --force

# Set up CMake configurations
CMAKE_CONFIGS="\
  -DLLVM_TARGET_ARCH=$ARCH \
  -DLLVM_TARGETS_TO_BUILD=$ARCH \
  -DLLVM_BUILD_TESTS=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_BUILD_UTILS=OFF \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_BUILD_RUNTIMES=OFF \
  -DLLVM_INCLUDE_RUNTIMES=OFF \
  -DLLVM_BUILD_EXAMPLES=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_BUILD_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DMLIR_BUILD_MLIR_C_DYLIB=1 \
  -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
  -DMLIR_ENABLE_EXECUTION_ENGINE=ON \
  -DLLVM_BUILD_TOOLS=ON \
  -DLLVM_INCLUDE_TOOLS=ON \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DLLVM_ENABLE_PROJECTS=mlir"

CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=Release"
cmake "$SOURCE_DIR/llvm-project/llvm" $CMAKE_CONFIGS
make llvm-tblgen mlir-tblgen mlir-linalg-ods-yaml-gen mlir-pdll -j $NUM_JOBS

popd