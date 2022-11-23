#!/bin/bash

set -e -x

while getopts "v:p:" arg; do
  case "$arg" in
  v)
    py_version="$OPTARG"
    ;;
  p)
    platform="$OPTARG"
    ;;
  *)
    usage
    ;;
  esac
done

# install python3 deps for mlir python bindinds
rm -rf llvm_miniconda
if [[ "$OSTYPE" == "darwin"* ]]; then
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -O miniconda.sh
else
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
fi
bash miniconda.sh -b -p llvm_miniconda

# strip this scripts args in order not to pass to sourced script
# https://stackoverflow.com/a/33654945

CONDA_EXE=llvm_miniconda/bin/conda
$CONDA_EXE create -n mlir -c conda-forge python="$py_version" -y
export PATH=llvm_miniconda/envs/mlir/bin:$PATH

python3 -m pip install -r "$SOURCE_DIR/llvm-project/mlir/python/requirements.txt"
python3 -m pip uninstall -y pybind11
python3 -m pip install pybind11==2.10.1 cmake==3.24.0 -U --force