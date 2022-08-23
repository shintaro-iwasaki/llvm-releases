#!/bin/bash

set -x

# 1. Prepare build directories
SOURCE_DIR="$(dirname $0)"
BUILD_DIR="$(mktemp -d)"
echo "Using a temporary directory for the build: $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cp -r "$SOURCE_DIR/scripts" "$BUILD_DIR/scripts"

# 2. Create a tarball of llvm-project
echo "Downloading llvm-project"
cd llvm-project
git submodule update --init --recursive
echo "git log -1"
git log -1
cd ..
echo "Creating llvm-project.tar.gz"
tar -czf "$BUILD_DIR/llvm-project.tar.gz" llvm-project

# 3. Run a docker
DOCKER_TAG="staging"
DOCKER_REPOSITORY="clang-ubuntu"
DOCKER_FILE_PATH="scripts/Dockerfile"

build_type="MinSizeRel"
install_dir_name="clang+llvm-14.0.0-x86_64-linux-gnu-ubuntu-18.04-assert"

echo "Building $DOCKER_REPOSITORY:$DOCKER_TAG using $DOCKER_FILE_PATH"
docker build -m 16g -t $DOCKER_REPOSITORY:$DOCKER_TAG --build-arg build_type=$build_type --build-arg install_dir_name=$install_dir_name -f "$BUILD_DIR/$DOCKER_FILE_PATH" "$BUILD_DIR"

# 4. Copy a created tarball.
# We cannot directly copy a file from a Docker image, so first create
# a Docker container, copy it, and remove a Docker container.
DOCKER_ID="$(docker create $DOCKER_REPOSITORY:$DOCKER_TAG)"
docker cp "$DOCKER_ID:/tmp/${install_dir_name}.tar.xz" .
docker rm $DOCKER_ID
