# Releasing codehive

Every change to what codehive installs gets its own version number, so a version always names one exact build. Releases are git tags like `v1.2.3` on some of those versions. Pushing a tag publishes a GitHub release, with that version's section of [CHANGELOG.md](CHANGELOG.md) as the notes. Installs see the new release within a day.

Version numbers between releases are never tagged, so release numbers can skip: after `1.0.0`, the next release might be `1.0.3`.

## While working

In the same pull request as the change:

1. **Bump `VERSION`** if the change touches anything the installer installs or runs: `install.sh`, `uninstall.sh`, and everything under `bin/`, `lib/`, `libexec/`, `launcher/`, and `systemd/`. Count from the current `VERSION`, not the last release. Bump the major version if an existing install behaves differently or needs something from the user after updating, the minor version if something was added, and the patch version for fixes only. Changes to docs, the changelog, or the release workflow don't get a new version.
2. **Update [docs/manual-install.md](docs/manual-install.md)** if the change touches `install.sh` or what it installs. That page has to list exactly what the installer does.
3. **Add a line under Unreleased** in `CHANGELOG.md`, under **Added**, **Changed**, **Fixed**, or **Removed**. Write it for someone running codehive, not for someone reading the code: what's different for them, and anything they need to do.

An install that follows `main` reports the bumped version in `codehive version`. It gets no update notice until a release with a higher number comes out.

## Cutting a release

A release publishes whatever version `main` is at. `VERSION` is already right, so nothing gets bumped.

1. In `CHANGELOG.md`, rename **Unreleased** to `[1.2.3] - YYYY-MM-DD`, using the version in `VERSION`, add a new empty **Unreleased** above it, and update the links at the bottom.
2. Merge that to `main`, then tag the merge and push the tag:

   ```bash
   git checkout main && git pull
   git tag "v$(cat VERSION)"
   git push origin "v$(cat VERSION)"
   ```

The [Release workflow](.github/workflows/release.yml) checks that the tag matches `VERSION` and that the changelog has a section for it, then publishes the release. If it fails, fix the problem on `main`, delete the tag (`git push origin :v1.2.3 && git tag -d v1.2.3`), and tag again.
