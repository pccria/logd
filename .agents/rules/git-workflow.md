---
trigger: always_on
---

# Git Workflow & Branch Invariants

Adhere to the following branch protection and delivery workflow across this repository:

## 1. Master Branch Protection
- **`master` strictly accepts Pull Requests only**: Never push directly to `master` under any circumstances, and never instruct the user to push directly to `master`.
- **Working Branches**: Active development takes place on `dev` or dedicated feature/fix branches (e.g., `feat/...`, `fix/...`, `docs/...`).

## 2. Delivering Changes
- Always deliver changes by pushing to `dev` (or the feature branch) and opening a Pull Request targeting `master` via GitHub CLI (`gh pr create --base master ...`).
- When staging changes, ensure unrelated in-progress work in other monorepo packages is not inadvertently included in the commit.
