#!/bin/bash

set -e -x

while getopts "v:j:" arg; do
  case "$arg" in
  v)
    py_version="$OPTARG"
    ;;
  j)
    num_jobs="$OPTARG"
    ;;
  *)
    ;;
  esac
done


bash ./setup_python.bash -v $py_version


CURRENT_DIR="$(pwd)"
echo $CURRENT_DIR
SOURCE_DIR="$CURRENT_DIR"
TABGEN_BUILDIR=$SOURCE_DIR/tblgen_buildecho

INSTALL_LLVM=$SOURCE_DIR/install_llvm
mkdir -p $INSTALL_LLVM

mkdir -p build
BUILD_DIR=$(pwd)/build
pushd "$BUILD_DIR"

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
  -DLLVM_HOST_TRIPLE=aarch64-unknown-linux-gnu \
  -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-unknown-linux-gnu \
  -DLLVM_ENABLE_PROJECTS=mlir \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_LLVM \
  -DPython3_EXECUTABLE=$SOURCE_DIR/llvm_miniconda/envs/mlir/bin/python3"

cmake "$SOURCE_DIR/llvm-project/llvm" \
    $CMAKE_CONFIGS \
    -DLLVM_TABLEGEN="$TABGEN_BUILDIR/bin/llvm-tblgen" \
    -DMLIR_TABLEGEN="$TABGEN_BUILDIR/bin/mlir-tblgen" \
    -DMLIR_LINALG_ODS_YAML_GEN="$TABGEN_BUILDIR/bin/mlir-linalg-ods-yaml-gen" \
    -DMLIR_PDLL_TABLEGEN="$TABGEN_BUILDIR/bin/mlir-pdll"

make install -j $num_jobs
cp bin/mlir-tblgen $INSTALL_LLVM/bin/mlir-tblgen
cp bin/llvm-tblgen $INSTALL_LLVM/bin/llvm-tblgen
cp bin/mlir-linalg-ods-yaml-gen $INSTALL_LLVM/bin/mlir-linalg-ods-yaml-gen
cp bin/mlir-pdll $INSTALL_LLVM/bin/mlir-pdll
cp -R -L "$INSTALL_LLVM" "${SOURCE_DIR}/${INSTALL_LLVM}"

popd

#    -DCMAKE_CXX_FLAGS="-target arm64-linux-eabi" \
#    -DCMAKE_C_FLAGS="-target arm64-linux-eabi" \
#    -DCMAKE_EXE_LINKER_FLAGS='-arch arm64' \
