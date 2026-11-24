# Changelog

## 2026-11-25

- [CI run 45427356234](https://github.com/pulipulichen/realer-xpad/actions/runs/45427356234) at `9ca2996`: all builds passed, including the Flatpak SDK update and AppImage smoke test. The workflow skipped publishing because the run was triggered by a push to `main`, with no `v*` tag.
- Publish each successful AppImage build on `main` directly to GitHub Releases as a prerelease, using a preview tag tied to the workflow run. The version-tag release job still publishes the full set of packages.

## 2026-11-24

- [CI run 45425319205](https://github.com/pulipulichen/realer-xpad/actions/runs/45425319205) at `7b2c0d8`: the Flatpak builder failed while updating `org.gnome.Sdk//51` with `Invalid cross-device link`, then exited with code 139. Lint, both GTK test jobs, the Linux build, and AppImage passed.
- Mount the preinstalled Flatpak runtimes in a fresh Docker volume so OSTree can update SDK deployments on a writable filesystem. The next CI run on `main` verifies the build and bundle upload. This change does not create a release tag.
