#  Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
#  See https://llvm.org/LICENSE.txt for license information.
#  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

from setuptools import find_namespace_packages, setup

packages = find_namespace_packages(
    include=[
        "mlir",
        "mlir.*",
    ],
)

setup(
    name="mlir_python_bindings",
    include_package_data=True,
    packages=packages,
    zip_safe=False,
)
