# Contributing Guidelines

Thank you for contributing to this project! Because this script is built specifically for **disposable, zero-footprint macOS containers**, all changes must preserve ephemeral isolation, idempotency, and shell safety.

## Development Workflow

1. **Fork & Branch:**
   Fork the repository and create a branch from `main` using a clear prefix:
   * `fix/` for bug fixes (e.g., `fix/sdkmanager-license-prompt`)
   * `feat/` for new options or tool support (e.g., `feat/branch-checkout`)
   * `docs/` for documentation updates (e.g., `docs/update-token-scopes`)

2. **Test in a Fresh Disposable Container:**
   Always validate changes on a clean container boot rather than a pre-warmed environment:
   ```bash
   source "\$HOME/drive/nomac/start.sh" "Test User" "test@example.com" "https://github.com"
   ```

3. **Core Script Rules:**
   * **Zero Persistent Footprint:** Never write downloaded binaries, caches, decoded JSON credentials, or cloned repositories into `$HOME/drive`. All artifacts must stay inside `$HOME`, `/opt/homebrew`, or `/tmp`.
   * **Source-Safe Execution:** Do not add `set -e` at the top level of `start.sh`. Because users invoke the script with `source`, `set -e` will immediately terminate their entire terminal window if a non-critical command fails.
   * **Architecture Compatibility:** Ensure any binary or Homebrew formula works on both **Apple Silicon (`arm64`)** and **Intel (`x86_64`)** macOS images.
   * **Non-Interactive Support:** Any new authentication step must support environment-variable injection for headless runs while gracefully falling back to interactive login if unset.

4. **Verification Checklist:**
   Before opening a Pull Request, verify all toolchains pass inside the fresh container:
   * `flutter doctor` (Android toolchain and Xcode show green checkmarks)
   * `shorebird doctor`
   * `firebase --version` and `flutterfire --version`
   * `gh auth status`

5. **Documentation:**
   Update `README.md` if you introduce any new environment variables, positional arguments, or Homebrew packages.
