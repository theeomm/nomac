## Summary
<!-- Briefly describe what this Pull Request changes and why. -->

## Type of Change
- [ ] Bug fix (non-breaking change that resolves an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Toolchain / SDK version update
- [ ] Documentation update (`README.md`, `CONTRIBUTING.md`)

## Ephemeral Container Verification
Please confirm you tested `source start.sh` on a **freshly booted macOS container**:

- [ ] **Zero persistent footprint:** Confirmed no SDKs, caches, or secret files are written to `$HOME/drive`.
- [ ] **Source-safe:** Confirmed sourcing `start.sh` does not crash or close the terminal on error.
- [ ] **`flutter doctor` passed** (Android SDK & Xcode toolchains healthy).
- [ ] **`shorebird doctor` passed**.
- [ ] **`firebase --version` & `flutterfire --version` passed**.
- [ ] **`gh auth status` & repository auto-clone passed**.
- [ ] **`README.md` updated** (if new environment variables or arguments were added).

## Test Output / Notes
<!-- Optional: Paste relevant `flutter doctor` or terminal output from your container test run. -->
