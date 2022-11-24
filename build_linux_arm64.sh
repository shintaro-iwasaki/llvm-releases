#!/bin/bash

set -e -x

ldd --version ldd

if [ ! -d "$SOURCE_DIR/llvm_miniconda" ]; then
  bash setup_python.sh
fi
export PATH=$SOURCE_DIR/llvm_miniconda/envs/mlir/bin:$PATH

Python3_EXECUTABLE="$SOURCE_DIR/llvm_miniconda/envs/mlir/bin/python3"
echo $Python3_EXECUTABLE

pushd "$BUILD_DIR"

function sedinplace {
  if ! sed --version 2>&1 | grep -i gnu >/dev/null; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}
# prevent recursive NATIVE build
sedinplace 's/if(LLVM_USE_HOST_TOOLS)/if(0)/g' $SOURCE_DIR/llvm-project/llvm/cmake/modules/TableGen.cmake
sedinplace 's/if(LLVM_USE_HOST_TOOLS)/if(0)/g' $SOURCE_DIR/llvm-project/mlir/tools/mlir-linalg-ods-gen/CMakeLists.txt
sedinplace 's/if(CMAKE_CROSSCOMPILING AND NOT LLVM_CONFIG_PATH)/if(0)/g' $SOURCE_DIR/llvm-project/llvm/tools/llvm-config/CMakeLists.txt
sedinplace 's/if(CMAKE_CROSSCOMPILING)/if(0)/g' $SOURCE_DIR/llvm-project/llvm/tools/llvm-shlib/CMakeLists.txt

unset CMAKE_CONFIGS
CMAKE_CONFIGS="\
  -GNinja \
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
  -DLLVM_HOST_TRIPLE=aarch64-unknown-linux-gnu \
  -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-unknown-linux-gnu \
  -DLLVM_ENABLE_PROJECTS=mlir \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_LLVM \
  -DLLVM_TARGETS_TO_BUILD=AArch64 \
  -DPython3_EXECUTABLE=$Python3_EXECUTABLE"

echo $CMAKE_CONFIGS

ls -l $TABGEN_BUILDIR/bin
$TABGEN_BUILDIR/bin/llvm-tblgen --version

cmake "$SOURCE_DIR/llvm-project/llvm" \
    $CMAKE_CONFIGS \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_TABLEGEN="$TABGEN_BUILDIR/bin/llvm-tblgen" \
    -DMLIR_TABLEGEN="$TABGEN_BUILDIR/bin/mlir-tblgen" \
    -DMLIR_LINALG_ODS_YAML_GEN="$TABGEN_BUILDIR/bin/mlir-linalg-ods-yaml-gen" \
    -DMLIR_PDLL_TABLEGEN="$TABGEN_BUILDIR/bin/mlir-pdll"

ninja install -j $NUM_JOBS

cp bin/mlir-tblgen $INSTALL_LLVM/bin/mlir-tblgen
cp bin/llvm-tblgen $INSTALL_LLVM/bin/llvm-tblgen
cp bin/mlir-linalg-ods-yaml-gen $INSTALL_LLVM/bin/mlir-linalg-ods-yaml-gen
cp bin/mlir-pdll $INSTALL_LLVM/bin/mlir-pdll

popd
