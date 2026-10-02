# Tests

The tests use [bats](https://github.com/bats-core/bats-core) 1.5 or newer (`apt install bats`).

| File | What it checks | Where it can run |
|---|---|---|
| `unit.bats` | The installer, `codehive`, the sync, the trust script, and the log filter, in a throwaway home folder with `systemctl`, `loginctl`, `sudo`, and Claude Code stood in for | Anywhere, including a machine with codehive installed |
| `integration.bats` | A real install driven through real systemd user services, with Claude Code stood in for | Only a throwaway machine |

`fake-claude` stands in for Claude Code. `claude remote-control` records how it was started in `~/.fake-claude/<folder>.args` and then waits like a server, so its unit stays active. `claude auth status` reports a claude.ai login. No Claude account is needed.

## Sandboxed tests

```bash
bats test/unit.bats
```

## Integration tests

**Don't run these on a machine you use.** They install codehive for the current user, put `fake-claude` at `~/.local/bin/claude`, start and stop real services, and uninstall everything with `--purge` at the end. They refuse to start if codehive or Claude Code is already installed, or from inside a codehive server, but use a throwaway VM or container anyway.

CI runs them on every push. To run them yourself, on a throwaway machine with a systemd user manager and lingering turned on:

```bash
CODEHIVE_INTEGRATION=1 bats test/integration.bats
```
