# LLVM Binary Publisher

This repository is to create and push LLVM binaries using GitHub Actions.
1. The developer first creates a pull request (PR) that updates LLVM code and build scripts.
2. When the PR is pushed to `main`, LLVM binraries are created and added to a specified repository.

## How to update LLVM using this repository

First, create a commit that updates LLVM.

```sh
cd <this-repository>
# 1. Update llvm-project
git submodule update --init --depth 1 llvm-project
pushd llvm-project
git checkout <new-llvm-commit-id>
popd ../

# 2. Update build scripts (if needed)
vi build_llvm.bash

# 3. Commit these changes
git add -u
git commit
git push
```

Then, create a PR to the main branch of this repository. When a PR is merged, created binaries are pushed to the specified repository.

You can test run the build like this 

```sh
bash build_llvm.bash -v 3.11 -o here -p local -a arm64 -c release -j 4
```
