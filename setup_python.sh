#!/bin/bash

set -e -x

# install python3 deps for mlir python bindings
rm -rf llvm_miniconda
if [[ "$OSTYPE" == "darwin"* ]]; then
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -O miniconda.sh
else
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
fi
bash miniconda.sh -b -p $SOURCE_DIR/llvm_miniconda

# strip this scripts args in order not to pass to sourced script
# https://stackoverflow.com/a/33654945

CONDA_EXE=$SOURCE_DIR/llvm_miniconda/bin/conda
$CONDA_EXE create -n mlir -c conda-forge python="$PY_VERSION" -y
export PATH=$SOURCE_DIR/llvm_miniconda/envs/mlir/bin:$PATH
python3 -m pip install pybind11==2.10.1 cmake==3.24.0 numpy PyYAML dataclasses -U --force