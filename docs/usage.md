# Daily use

| Task | How |
|---|---|
| Work on a project | Open the project from the session list (iOS app **Code** tab, claude.ai/code, or Desktop **Code** tab) and start a session |
| Create a project from a client | Open **launcher** and ask for a new project |
| Create a project over SSH | `codehive new <name>`. Add `--in <folder>` (a project folder's name, like `work`, or its path) to use a folder other than the first. |
| Add an existing project | `git clone ... ~/projects/name`, review it, then `codehive trust ~/projects/name`. With `AUTO_TRUST=1`, it's picked up right away without that step. |
| Exclude a project | `touch ~/projects/name/.no-rc` |
| Remove a project | Delete or move the folder. Its server stops right away. |
| See everything | `codehive status` |
| View logs | `codehive logs <name>` shows the last 50 lines. Extra arguments go to `journalctl` instead, like `-f` to follow or `--since today`. |
| Restart a server | `codehive restart <name>`, or `codehive restart` for all of them, including the launcher |
| Match servers to project folders now | `codehive sync`. It runs every minute on its own and whenever a project folder changes. |
| List project folders | `codehive dirs` |
| Trust a folder | `codehive trust <path>...` (one or more folders). Its server starts right away. |
| Stop trusting a folder | `codehive untrust <path>...`. Its server stops. |
| See the installed version | `codehive version`. This also checks for a newer one. |
| Update codehive | `codehive update` (see [Updating](updating.md)) |
| Uninstall | `codehive uninstall` (see [Uninstall](uninstall.md)) |
| Show the commands | `codehive help` |

`<name>` is a project's folder name, a path (when two project folders have a project with the same name), or `launcher`.

Run `codehive restart`, `update`, and `uninstall` from SSH or a console, not from a Claude session (see [Updating](updating.md)).
