# Git and non-git projects

A project runs in one of two modes, and `codehive status` shows which:

- **worktree**: the folder is a git repo with at least one commit.
- **same-dir**: anything else, including a git repo with no commits yet.

Projects made with `codehive new`, or by asking the launcher, are always git repos with a commit, so they start in worktree mode. A project ends up in same-dir mode when you create the folder yourself without `git init`, or add an existing folder that isn't a git repo.

**What worktree mode means in practice:**

- Each session works in its own git worktree, on its own branch, so sessions running at the same time can't overwrite each other's files.
- A session starts from the project's last commit. Uncommitted changes in the project folder aren't in it.
- A session's changes stay on its branch. They don't show up in the project folder, or to anything else reading it, until you merge that branch.
- Worktrees take up disk space and stay until they're removed. `git worktree list` in the project shows them.

**What same-dir mode means in practice:**

- Every session edits the project folder directly, and changes are visible right away to everything else that reads it, like an editor over SSH or a sync tool.
- There are no branches and nothing to merge.
- Sessions running at the same time share the folder and can overwrite each other's edits, so run one at a time.

Same-dir mode suits notes, documents, scratch space, and folders that another tool syncs. Worktree mode suits code, and anything you'd want to review before it lands.

**Switching modes.** The mode follows the folder, and the sync switches it within a minute. Switching stops the project's server and starts a new one, so sessions open in it are cut off.

- To switch a project to worktree mode, make it a git repo with a commit.
- **`codehive new <name>` on an existing folder turns it into a git repo.** If a folder with that name already exists, `codehive new` runs `git init` in it and makes an empty initial commit, so the project switches to worktree mode. Pick a new name if you don't want that.
- **Deleting a project's `.git` folder switches it back to same-dir mode.**
