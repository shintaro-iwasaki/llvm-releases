# Base Image
FROM ubuntu:18.04

# Install build dependencies of llvm.
RUN apt update && apt install -y git build-essential make wget python3

# Use newer CMake for LLVM
RUN cd tmp && wget -q https://github.com/Kitware/CMake/releases/download/v3.24.0/cmake-3.24.0-linux-x86_64.tar.gz && tar -xf cmake-3.24.0-linux-x86_64.tar.gz

# Copy necessary files from the host.  A tarball is automatically expanded.
ADD scripts /tmp/scripts
ADD llvm-project.tar.gz /tmp

# Compile LLVM
ARG build_type
ARG install_dir_name
RUN mkdir /tmp/llvm-project/build && cd /tmp/llvm-project/build && /tmp/cmake-3.24.0-linux-x86_64/bin/cmake /tmp/llvm-project/llvm -DLLVM_ENABLE_PROJECTS="mlir" -DCMAKE_BUILD_TYPE=${build_type} -DLLVM_TARGETS_TO_BUILD="X86;NVPTX;AMDGPU" -DCMAKE_INSTALL_PREFIX="/tmp/${install_dir_name}" -DLLVM_ENABLE_ASSERTIONS=True
RUN cd /tmp/llvm-project/build && make -j $(nproc) install

# Create a tarball
RUN cd /tmp && tar -cJf "${install_dir_name}.tar.xz" "${install_dir_name}"
