# Releasing

codehive is built every night. A build becomes a release only after you've tried it on your own server. [DEVELOPING.md](DEVELOPING.md) covers the workflow before that: developing, and testing every change on GitHub.

## Version numbers

Versions are calendar versions in the form `YYYY.0M.0D`: the UTC date of the build, with zero-padded month and day, such as `2026.10.03`. In the rare case that a second build runs on the same day, it gets a counter: `2026.10.03.1`, `2026.10.03.2`. Each build is tagged `v` plus the version, for example `v2026.10.03`.

A version says when a build was made. It doesn't say how big the change was. Changes that need something from the user are marked in the changelog instead (see below). A build keeps its version when it's promoted to a release.

## Checks on every change

The [CI workflow](.github/workflows/ci.yml) runs on every branch pushed to this repo, and on pull requests from forks:

1. **Lint.** `shellcheck` and `bash -n` on the shell scripts, and a syntax check of the Python ones.
2. **Sandboxed tests** ([test/unit.bats](test/unit.bats)). They run the installer, `codehive`, the sync, and the trust script in a throwaway home folder, with `systemctl` and Claude Code stood in for.
3. **Integration tests** ([test/integration.bats](test/integration.bats)). They install codehive for real and drive real systemd user services through `codehive new`, `trust`, `untrust`, `.no-rc`, deleted folders, `restart`, `off` and `on`, reinstalling, and `uninstall`. Claude Code is replaced by [test/fake-claude](test/fake-claude), so no Claude account is needed.
4. **The real Claude Code.** A job installs it, not signed in, and fails if the options codehive passes to `claude remote-control` are no longer in its help text, or `claude auth status` no longer prints the JSON the installer reads. Signed out, Remote Control won't run at all, so this can't tell whether an option still behaves the same.

Both test suites run on Ubuntu 24.04 directly on the runner, and on Debian 13 booted with systemd in a container ([test/debian13.Dockerfile](test/debian13.Dockerfile)), each on x86_64 and ARM64. See [test/README.md](test/README.md) for what each covers.

What the tests can't cover: whether Remote Control works, and Claude Code changes the check above doesn't see, such as an option that changed meaning or how workspace trust is stored. That's what trying a build on your server is for (see below).

## The nightly build

The [Nightly workflow](.github/workflows/nightly.yml) runs at 03:00 UTC on `main`. It looks at what changed since the last tag. If nothing the installer installs has changed (`install.sh`, `uninstall.sh`, and everything under `bin/`, `lib/`, `libexec/`, `launcher/`, and `systemd/`), it stops, so days with only docs changes don't get a build. Otherwise it:

1. Runs CI on that commit. If CI fails, nothing else happens.
2. Writes the new version to `VERSION`.
3. Moves everything under **Unreleased** in `CHANGELOG.md` into a new section for that version, and updates the links at the bottom.
4. Commits both files to `main` as `codehive <version>`, tags that commit, and pushes both together.
5. Publishes a GitHub **prerelease** with that version's changelog section as the notes.

The installer and `codehive update` skip prereleases, so a nightly build reaches nobody until it's promoted. Anyone can still install one with `--ref <tag>`.

To build right away, for example to ship a fix, run the workflow by hand on `main` from the Actions tab or with `gh workflow run nightly.yml`. If the build fails, fix the problem on `main` and run it again. Nothing is tagged or published until the push succeeds, so a failed run leaves nothing to clean up. If `main` moved while CI was running, the push fails the same way; run the workflow again.

The workflow pushes to `main` with the built-in `GITHUB_TOKEN`. If `main` is protected, allow GitHub Actions to push to it.

## Promoting a build to a release

Promoting is checked on your own server, signed in to your own Claude account. No test machine is signed in to Claude, so this is the only check with real Remote Control. Do it over SSH, not from a Claude session.

1. Install the prerelease and restart the servers:
   ```bash
   codehive update --ref v2026.10.03
   codehive restart
   ```
2. Check what the tests can't. From a client, open a project and the launcher, start a session in each, and make a project from the launcher. Try whatever the build changed.
3. If it works, run the [Promote workflow](.github/workflows/promote.yml) from the Actions tab or with `gh workflow run promote.yml -f tag=v2026.10.03`. Leave out the tag to promote the newest prerelease. Then go back to following releases: `codehive update --ref latest`.
4. If it doesn't, go back to the release you had, and fix the problem on `main`:
   ```bash
   codehive update --ref <previous tag>
   codehive restart
   ```

While you're checking, your server runs a build that only CI has tested. A build that passes CI but breaks Remote Control leaves your servers down until you roll back.

Promoting marks the build as the latest release and replaces its notes with the notes of every nightly build since the last release, so `codehive update` shows everything that changed. Nothing is rebuilt. Installs see the new release within a day.

A build that turns out to be bad after it's promoted can be pulled by marking it as a prerelease again on the releases page. Installs that haven't updated yet then go back to being offered the release before it. Installs that already have it can go back with `codehive update --ref <previous tag>`, and then return with `--ref latest` once a fixed build is promoted.

## Upkeep

- **The nightly schedule turns itself off** if the repository has no activity for 60 days. GitHub does this for scheduled workflows in public repositories. Turn it back on in the Actions tab or with `gh workflow enable nightly.yml`.
- **The runner images are pinned** to `ubuntu-24.04` and `ubuntu-24.04-arm`, because [docs/requirements.md](docs/requirements.md) names those versions. When GitHub retires them, update both together.
- **GitHub-hosted runners are free** for public repositories, with no limit on minutes. If this repository becomes private, minutes count against the account's plan.

## While working

In the same pull request as the change:

1. **Leave `VERSION` alone.** Only the nightly build changes it.
2. **Update [docs/manual-install.md](docs/manual-install.md)** if the change touches `install.sh` or what it installs. That page has to list exactly what the installer does.
3. **Add or update tests** in `test/` for what the change does, and push the branch to see them pass in CI. Don't run the integration tests or the installer on your own server (see [DEVELOPING.md](DEVELOPING.md)).
4. **Add a line under Unreleased** in `CHANGELOG.md`, under **Added**, **Changed**, **Fixed**, or **Removed**. Write it for someone running codehive, not for someone reading the code: what's different for them, and anything they need to do. If an existing install behaves differently after updating, or needs something from the user, start the line with **Action needed:**.

An install that follows `main` reports the version of the last nightly build in `codehive version`, even if it has changes from after that build.
