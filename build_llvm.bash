#!/bin/bash

set -e -x

# 0. Check
CURRENT_DIR="$(pwd)"
SOURCE_DIR="$CURRENT_DIR"
if [ ! -f "$SOURCE_DIR/llvm-project/llvm/CMakeLists.txt" ]; then
  echo "Error: $SOURCE_DIR/llvm-project/llvm/CMakeLists.txt is not found."
  echo "       Did you run git submodule update --init --recursive?"
  exit 1
fi

# Parse arguments
install_prefix=""
platform=""
build_config=""
num_jobs=8

usage() {
  echo "Usage: bash build_llvm.sh -o INSTALL_PREFIX -p PLATFORM -c CONFIG [-j NUM_JOBS]"
  echo "Ex: bash build_llvm.sh -o llvm-14.0.0-x86_64-linux-gnu-ubuntu-20.04 -p docker_ubuntu_20.04 -c assert -j 16"
  echo "INSTALL_PREFIX = <string> # \${INSTALL_PREFIX}.tar.xz is created"
  echo "PLATFORM       = {local|docker_ubuntu_20.04}"
  echo "CONFIG         = {release|assert|debug}"
  echo "NUM_JOBS       = {1|2|3|...}"
  exit 1;
}

while getopts "a:o:p:c:j:v:" arg; do
  case "$arg" in
    a)
      arch="$OPTARG"
      ;;
    o)
      install_prefix="$OPTARG"
      ;;
    p)
      platform="$OPTARG"
      ;;
    c)
      build_config="$OPTARG"
      ;;
    j)
      num_jobs="$OPTARG"
      ;;
    v)
      py_version="$OPTARG"
      ;;
    *)
      usage
      ;;
  esac
done

if [ x"$py_version" == x ] || [ x"$arch" == x ] || [ x"$install_prefix" == x ] || [ x"$platform" == x ] || [ x"$build_config" == x ]; then
  usage
fi

# Set up CMake configurations
if [ x"$arch" == x"x86_64" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} \
    -DLLVM_TARGETS_TO_BUILD=X86"
fi

CMAKE_CONFIGS="-G Ninja \
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
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DMLIR_BUILD_MLIR_C_DYLIB=1 \
  -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
  -DLLVM_BUILD_TOOLS=ON \
  -DLLVM_INCLUDE_TOOLS=ON \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DLLVM_ENABLE_PROJECTS=mlir"

if [ x"$build_config" == x"release" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=Release"
elif [ x"$build_config" == x"assert" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=MinSizeRel -DLLVM_ENABLE_ASSERTIONS=True"
elif [ x"$build_config" == x"debug" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=Debug"
elif [ x"$build_config" == x"relwithdeb" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=RelWithDebInfo"
else
  usage
fi

function tmpdir() {
  # Create a temporary build directory
  BUILD_DIR="$(mktemp -d)"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  echo "$BUILD_DIR"
}

function sedinplace {
    if ! sed --version 2>&1 | grep -i gnu > /dev/null; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# mkdir -p build
# BUILD_DIR=build
BUILD_DIR=$(tmpdir)
export XZ_OPT='-T0 -9'

if [ x"$platform" == x"local" ]; then
  # Build LLVM locally (eg on the x86 mac GHA instance)

  # install python3 deps for mlir python bindinds
  rm -rf $HOME/llvm_miniconda
  if [[ "$OSTYPE" == "darwin"* ]]; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -O ~/miniconda.sh
  else
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
  fi
  bash ~/miniconda.sh -b -p $HOME/llvm_miniconda

  # strip this scripts args in order not to pass to sourced script
  # https://stackoverflow.com/a/33654945

  CONDA_EXE=$HOME/llvm_miniconda/bin/conda
  $CONDA_EXE create -n mlir -c conda-forge python="$py_version" -y
  export PATH=$HOME/llvm_miniconda/envs/mlir/bin:$PATH

  python3 -m pip install -r "$SOURCE_DIR/llvm-project/mlir/python/requirements.txt"
  python3 -m pip uninstall -y pybind11
  python3 -m pip install pybind11==2.10.1
  python3 -m pip install ninja==1.10.2 cmake==3.24.0 -U --force

  echo $(ninja --version) || exit 1
  echo $(cmake --version) || exit 1

  pushd "$BUILD_DIR"

  CMAKE_CONFIGS="\
    ${CMAKE_CONFIGS} \
    -DCMAKE_MAKE_PROGRAM=$(which ninja)
    -DCMAKE_INSTALL_PREFIX=$BUILD_DIR/$install_prefix \
    -DPython3_EXECUTABLE=$(which python3)"

  if [ x"$arch" == x"arm64" ]; then
    # mkdir -p tblgen_build
    # TABGEN_BUILDIR=tblgen_build
    TABGEN_BUILDIR=$(tmpdir)
    pushd "$TABGEN_BUILDIR"

    CMAKE_CONFIGS="${CMAKE_CONFIGS} \
      -DLLVM_TARGET_ARCH=AArch64 \
      -DLLVM_TARGETS_TO_BUILD=AArch64 \
      -DLLVM_HOST_TRIPLE=arm64-apple-darwin21.6.0 \
      -DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-darwin21.6.0"

    # compile the various gen things for local host arch first (in order to use in the actual td generation in the next step)
    # TODO LLVM_USE_HOST_TOOLS???
    cmake "$SOURCE_DIR/llvm-project/llvm" \
      $CMAKE_CONFIGS \
      -DCMAKE_BUILD_TYPE=Release

    ninja llvm-tblgen mlir-tblgen mlir-linalg-ods-yaml-gen mlir-pdll

    # check for bad arch (fail fast)
    echo $($TABGEN_BUILDIR/bin/llvm-tblgen -version) || exit 1

    popd

    cmake "$SOURCE_DIR/llvm-project/llvm" \
      $CMAKE_CONFIGS \
      -DCMAKE_CROSSCOMPILING=True \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_CXX_FLAGS='-target arm64-apple-macos -mcpu=apple-m1' \
      -DCMAKE_C_FLAGS='-target arm64-apple-macos -mcpu=apple-m1' \
      -DCMAKE_EXE_LINKER_FLAGS='-arch arm64' \
      -DLLVM_TABLEGEN="$TABGEN_BUILDIR/bin/llvm-tblgen" \
      -DMLIR_TABLEGEN="$TABGEN_BUILDIR/bin/mlir-tblgen" \
      -DMLIR_LINALG_ODS_YAML_GEN="$TABGEN_BUILDIR/bin/mlir-linalg-ods-yaml-gen" \
      -DMLIR_PDLL_TABLEGEN="$TABGEN_BUILDIR/bin/mlir-pdll"

  else

    cmake "$SOURCE_DIR/llvm-project/llvm" $CMAKE_CONFIGS

  fi

  ninja install
  cp bin/mlir-tblgen $install_prefix/bin/mlir-tblgen
  cp -R -L "$install_prefix" "${CURRENT_DIR}/${install_prefix}"
  popd

elif [ x"$platform" == x"docker_ubuntu_20.04" ]; then
  # Prepare build directories
  cp -r "$SOURCE_DIR/scripts" "$BUILD_DIR/scripts"

  # Create a tarball of llvm-project
  echo "Creating llvm-project.tar.gz"
  pushd "$SOURCE_DIR"
  tar -czf "$BUILD_DIR/llvm-project.tar.gz" llvm-project
  popd

  # Run a docker
  DOCKER_TAG="build"
  DOCKER_REPOSITORY="clang-docker"
  DOCKER_FILE_PATH="scripts/docker_ubuntu20.04/Dockerfile"

  echo "Building $DOCKER_REPOSITORY:$DOCKER_TAG using $DOCKER_FILE_PATH"
  docker build -t $DOCKER_REPOSITORY:$DOCKER_TAG \
    --build-arg py_version="$py_version" \
    --build-arg cmake_configs="${CMAKE_CONFIGS}" \
    --build-arg num_jobs="${num_jobs}" \
    --build-arg install_dir_name="${install_prefix}" \
    --platform linux/x86_64 \
    -f "$BUILD_DIR/$DOCKER_FILE_PATH" "$BUILD_DIR"

  # Copy a created tarball from a Docker container.
  # We cannot directly copy a file from a Docker image, so first
  # create a Docker container, copy the tarball, and remove the container.
  DOCKER_ID="$(docker create $DOCKER_REPOSITORY:$DOCKER_TAG)"
  docker cp -L "$DOCKER_ID:/tmp/${install_prefix}" "${CURRENT_DIR}/"
  docker rm "$DOCKER_ID"
else
  rm -rf "$BUILD_DIR"
  usage
fi

# Remove the temporary directory
rm -rf "$BUILD_DIR"

echo "Completed!"