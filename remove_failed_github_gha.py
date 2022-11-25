from github import Github

# First create a Github instance:

# using an access token
g = Github(os.getenv("GHA_TOKEN"))

# Then play with your Github objects:
user = g.get_user()
for repo in ["mlir_python_bindings", "llvm-releases"]:
    repo = user.get_repo(repo)
    for wfr in repo.get_workflow_runs():
        if wfr.conclusion is not None and ("failure" in wfr.conclusion or "cancelled" in wfr.conclusion):
            wfr.delete()
        print(wfr.conclusion)
# for repo in g.get_user().get_repos():
#     print(repo.name)