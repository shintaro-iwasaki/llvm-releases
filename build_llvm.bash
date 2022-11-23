#!/bin/bash

set -e -x

function tmpdir() {
  # Create a temporary build directory
  BUILD_DIR="$(mktemp -d)"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  echo "$BUILD_DIR"
}

function sedinplace {
  if ! sed --version 2>&1 | grep -i gnu >/dev/null; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

usage() {
  echo "Usage: bash build_llvm.sh -o INSTALL_PREFIX -p PLATFORM -c CONFIG [-j NUM_JOBS]"
  echo "Ex: bash build_llvm.sh -o llvm-14.0.0-x86_64-linux-gnu-ubuntu-20.04 -p docker_ubuntu_20.04 -c assert -j 16"
  echo "INSTALL_PREFIX = <string> # \${INSTALL_PREFIX}.tar.xz is created"
  echo "PLATFORM       = {local|docker_ubuntu_20.04}"
  echo "CONFIG         = {release|assert|debug}"
  echo "NUM_JOBS       = {1|2|3|...}"
  exit 1
}

# 0. Check
CURRENT_DIR="$(pwd)"
SOURCE_DIR="$CURRENT_DIR"
TABGEN_BUILDIR=$SOURCE_DIR/tblgen_build

# Parse arguments
install_prefix=""
build_config=""
num_jobs=8

while getopts "a:o:p:c:v:j:p:" arg; do
  case "$arg" in
  a)
    arch="$OPTARG"
    ;;
  o)
    install_prefix="$OPTARG"
    ;;
  c)
    build_config="$OPTARG"
    ;;
  v)
    py_version="$OPTARG"
    ;;
  j)
    num_jobs="$OPTARG"
    ;;
  p)
    platform="$OPTARG"
    ;;
  *)
    usage
    ;;
  esac
done

mkdir -p build
BUILD_DIR=$(pwd)/build
pushd "$BUILD_DIR"

# Set up CMake configurations
CMAKE_CONFIGS="\
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
  -DLLVM_ENABLE_PROJECTS=mlir \
  -DCMAKE_INSTALL_PREFIX=$BUILD_DIR/$install_prefix \
  -DPython3_EXECUTABLE=$(which python3)"

if [ x"$build_config" == x"release" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=Release"
elif [ x"$build_config" == x"assert" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=MinSizeRel -DLLVM_ENABLE_ASSERTIONS=True"
elif [ x"$build_config" == x"debug" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_ASSERTIONS=True"
elif [ x"$build_config" == x"relwithdeb" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLLVM_ENABLE_ASSERTIONS=True"
fi

if [ x"$arch" == x"arm64" ] && [ x"$platform" == x"macos-latest" ]; then
  cmake "$SOURCE_DIR/llvm-project/llvm" \
    $CMAKE_CONFIGS \
    -DCMAKE_CROSSCOMPILING=True \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DMACOSX_DEPLOYMENT_TARGET="12.0" \
    -DCMAKE_CXX_FLAGS='-target arm64-apple-macos -mcpu=apple-m1' \
    -DCMAKE_C_FLAGS='-target arm64-apple-macos -mcpu=apple-m1' \
    -DCMAKE_EXE_LINKER_FLAGS='-arch arm64' \
    -DLLVM_TABLEGEN="$TABGEN_BUILDIR/bin/llvm-tblgen" \
    -DMLIR_TABLEGEN="$TABGEN_BUILDIR/bin/mlir-tblgen" \
    -DMLIR_LINALG_ODS_YAML_GEN="$TABGEN_BUILDIR/bin/mlir-linalg-ods-yaml-gen" \
    -DMLIR_PDLL_TABLEGEN="$TABGEN_BUILDIR/bin/mlir-pdll"
elif [ x"$arch" == x"arm64" ] && [ x"$platform" == x"ubuntu-latest" ]; then
  bash dockcross-linux-armv7-lts.sh bash build_linux_arm64.bash -v $py_version -j $num_jobs
elif [ x"$arch" == x"x86_64" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DLLVM_TARGETS_TO_BUILD=X86"
  cmake "$SOURCE_DIR/llvm-project/llvm" $CMAKE_CONFIGS
  make install -j $num_jobs
  cp bin/mlir-tblgen $install_prefix/bin/mlir-tblgen
  cp bin/llvm-tblgen $install_prefix/bin/llvm-tblgen
  cp bin/mlir-linalg-ods-yaml-gen $install_prefix/bin/mlir-linalg-ods-yaml-gen
  cp bin/mlir-pdll $install_prefix/bin/mlir-pdll
  cp -R -L "$install_prefix" "${CURRENT_DIR}/${install_prefix}"
fi

popd

echo "Completed!"
