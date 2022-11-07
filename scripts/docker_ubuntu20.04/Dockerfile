# Base Image
FROM ubuntu:20.04
SHELL ["/bin/bash", "-c"]

ARG cmake_configs
ARG install_dir_name
ARG num_jobs
ARG py_version

# Install build dependencies of llvm.
RUN apt update && apt install -y git build-essential wget ninja-build clang

RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
  bash ~/miniconda.sh -b -p $HOME/miniconda && \
  source $HOME/miniconda/bin/activate && \
  conda init && \
  conda init zsh && \
  conda create -n mlir -c conda-forge python="$py_version" -y
RUN source $HOME/miniconda/bin/activate && conda update -y conda

# Use newer CMake for LLVM
RUN cd tmp && wget -q https://github.com/Kitware/CMake/releases/download/v3.24.0/cmake-3.24.0-linux-x86_64.tar.gz && tar -xf cmake-3.24.0-linux-x86_64.tar.gz

# Copy necessary files from the host.  A tarball is automatically expanded.
ADD scripts /tmp/scripts
ADD llvm-project.tar.gz /tmp

# Compile LLVM
RUN $HOME/miniconda/envs/mlir/bin/python3 -m pip install --upgrade pip
RUN $HOME/miniconda/envs/mlir/bin/python3 -m pip install -r /tmp/llvm-project/mlir/python/requirements.txt
RUN $HOME/miniconda/envs/mlir/bin/python3 -m pip uninstall -y pybind11
RUN $HOME/miniconda/envs/mlir/bin/python3 -m pip install pybind11==2.10.1
RUN mkdir /tmp/llvm-project/build \
    && cd /tmp/llvm-project/build \
    && /tmp/cmake-3.24.0-linux-x86_64/bin/cmake \
    /tmp/llvm-project/llvm $cmake_configs \
    -DCMAKE_INSTALL_PREFIX="/tmp/${install_dir_name}" \
    -DPython3_EXECUTABLE="$HOME/miniconda/envs/mlir/bin/python3"
RUN cd /tmp/llvm-project/build && ninja install && cp bin/mlir-tblgen /tmp/${install_dir_name}/bin/mlir-tblgen

# Create a tarball
ENV XZ_OPT='-T0 -9'
