#!/bin/bash

set -e -x

if [[ ! -v SOURCE_DIR ]]; then
    echo "SOURCE_DIR is not set"
elif [[ -z "$SOURCE_DIR" ]]; then
    echo "SOURCE_DIR is set to the empty string"
else
    echo "SOURCE_DIR has the value: $SOURCE_DIR"
fi

while getopts "d:e:" arg; do
  case "$arg" in
  d)
    DOCKER_IMAGE="$OPTARG"
    ;;
  e)
    ENTRY_POINT="$OPTARG"
    ;;
  *)
    ;;
  esac
done

docker run \
  --rm \
  --platform linux/amd64 \
  -v $SOURCE_DIR:/work \
  -e SOURCE_DIR=/work \
  -e NUM_JOBS=$NUM_JOBS \
  -e BUILD_DIR=/work/build \
  -e INSTALL_LLVM=/work/llvm_install \
  -e PY_VERSION=$PY_VERSION \
  -e TABGEN_BUILDIR=/work/tblgen_build \
  --entrypoint $ENTRY_POINT \
  $DOCKER_IMAGE