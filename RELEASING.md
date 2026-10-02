# Releasing

codehive is built every night. Nobody cuts releases by hand.

## Version numbers

Versions are calendar versions in the form `YYYY.0M.0D`: the UTC date of the build, with zero-padded month and day, such as `2026.10.03`. In the rare case that a second build runs on the same day, it gets a counter: `2026.10.03.1`, `2026.10.03.2`. Each build is tagged `v` plus the version, for example `v2026.10.03`.

A version says when a build was made. It doesn't say how big the change was. Changes that need something from the user are marked in the changelog instead (see below).

## The nightly build

The [Nightly workflow](.github/workflows/nightly.yml) runs at 03:00 UTC. It looks at what changed on `main` since the last tag. If nothing the installer installs has changed (`install.sh`, `uninstall.sh`, and everything under `bin/`, `lib/`, `libexec/`, `launcher/`, and `systemd/`), it stops, so days with only docs changes don't get a build. Otherwise it:

1. Writes the new version to `VERSION`.
2. Moves everything under **Unreleased** in `CHANGELOG.md` into a new section for that version, and updates the links at the bottom.
3. Commits both files to `main` as `codehive <version>`, tags that commit, and pushes both together.
4. Publishes a GitHub release with that version's changelog section as the notes.

Installs see the new release within a day.

To build right away, for example to ship a fix, run the workflow by hand from the Actions tab or with `gh workflow run nightly.yml`. If the build fails, fix the problem on `main` and run it again. Nothing is tagged or published until the push succeeds, so a failed run leaves nothing to clean up.

The workflow pushes to `main` with the built-in `GITHUB_TOKEN`. If `main` is protected, allow GitHub Actions to push to it.

## While working

In the same pull request as the change:

1. **Leave `VERSION` alone.** Only the nightly build changes it.
2. **Update [docs/manual-install.md](docs/manual-install.md)** if the change touches `install.sh` or what it installs. That page has to list exactly what the installer does.
3. **Add a line under Unreleased** in `CHANGELOG.md`, under **Added**, **Changed**, **Fixed**, or **Removed**. Write it for someone running codehive, not for someone reading the code: what's different for them, and anything they need to do. If an existing install behaves differently after updating, or needs something from the user, start the line with **Action needed:**.

An install that follows `main` reports the version of the last nightly build in `codehive version`, even if it has changes from after that build.
