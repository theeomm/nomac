# Ephemeral macOS Flutter Development Environment Setup (nomac)

A zero-footprint bootstrap script (`start.sh`) built for disposable macOS containers on `nomac.app.` Only `start.sh` resides on your persistent drive (`$HOME/drive/nomac/start.sh`). Every toolchain, SDK, credential, and cloned repository lives on the container's ephemeral disk and is automatically wiped when the container closes.

## Installed Tools

* **OpenJDK 21** (via Homebrew)
* **Android SDK Command-Line Tools** (`platform-tools`, `platforms;android-36`, `build-tools;36.0.0` via Homebrew)
* **Flutter SDK** (Latest stable release via Homebrew)
* **Shorebird CLI** (Cloned and bootstrapped on `stable` branch)
* **Firebase CLI** (via Homebrew)
* **FlutterFire CLI** (Activated via Dart Pub)
* **GitHub CLI (`gh`)** (Configured as Git credential helper via `gh auth setup-git`)

## Usage

### 1. Interactive Setup (Manual Login)
Source `start.sh` and pass your Git `user.name`, `user.email`, and optional repository URL. If tokens are omitted, interactive authentication prompts will run where supported:

```bash
source "$HOME/drive/nomac/start.sh" "Your Name" "you@example.com" "https://github.com"
```

> **Note:** Always run with `source` (or `.`) so exported `PATH` variables apply immediately and your shell automatically `cd`s into `$HOME/<repo-name>`.

### 2. Headless / Non-Interactive Setup (With Tokens)
Configure your secrets in the nomac dashboard or pass your authentication tokens as environment variables when sourcing `start.sh`:

```bash
GH_TOKEN="ghp_your_github_token" \
SHOREBIRD_TOKEN="sb_api_your_shorebird_token" \
FIREBASE_SERVICE_ACCOUNT_BASE64="\$(base64 -i path/to/service-account.json)" \
source "\$HOME/drive/nomac/start.sh" "Your Name" "you@example.com" "https://github.com"
```

### 3. Local Windows/Linux Sync & Wrapper Scripts

Developing locally on **Windows or Linux**? You can sync your local project directory in real time using `nomac sync . --watch` and pass the synced path (`$HOME/drive/src/<folder>`) as the 3rd argument to `start.sh`:

```bash
source "\$HOME/drive/nomac/start.sh" "Your Name" "you@example.com" "\$HOME/drive/src/your_app"
```

#### Automated Local Wrappers (`scripts/`)
To automatically start a NoMac container, clone or pull the latest `theeomm/nomac` repo onto `$HOME/drive/nomac`, sync your local Flutter project, run `start.sh`, and display/open the browser desktop URL:

* **Linux / macOS / WSL / Git Bash (`scripts/nomac-dev.sh`):**
  ```bash
  ./scripts/nomac-dev.sh "Your Name" "you@example.com" --watch
  ```
* **Windows PowerShell (`scripts/nomac-dev.ps1`):**
  ```powershell
  .\scripts\nomac-dev.ps1 -GitName "Your Name" -GitEmail "you@example.com" -Watch
  ```

For the full end-to-end guide on **real-time file syncing**, **code signing**, **Shorebird iOS/macOS builds**, **TestFlight uploads**, and **App Store promotion**, see **[IOS_DEPLOYMENT.md](./IOS_DEPLOYMENT.md)**.


## Environment Variables Reference

| Variable | Required | Description | How to Obtain |
| :--- | :--- | :--- | :--- |
| **`GH_TOKEN`** | Optional | Personal Access Token for GitHub CLI (`gh`) and `gh auth setup-git`. Falls back to interactive `gh auth login` if unset. | GitHub **Settings -> Developer settings -> Personal access tokens** (needs `repo` and `read:org` scopes). |
| **`SHOREBIRD_TOKEN`** | Optional | API token for headless Shorebird releases and patches. Falls back to manual `shorebird login` if unset. | Run `shorebird login:ci` locally or generate an API key in the **Shorebird Console**. |
| **`FIREBASE_SERVICE_ACCOUNT_BASE64`** | Optional | Base64-encoded Firebase Service Account JSON file. Decoded to `/tmp/dev-tools/firebase-sa.json` and exported as `GOOGLE_APPLICATION_CREDENTIALS`. *(Recommended over `FIREBASE_TOKEN`)*. | Firebase Console **Project Settings -> Service accounts -> Generate new private key**, then encode with `base64 -i key.json`. |
| **`FIREBASE_TOKEN`** | Optional | Legacy CI token for Firebase CLI. Used only if `FIREBASE_SERVICE_ACCOUNT_BASE64` is not provided. | Run `firebase login:ci` on an authenticated machine. |
| **`REPO_URL`** | Optional | HTTPS URL of the Git repository to clone if not passed as the 3rd positional argument. | Copy the HTTPS clone URL from your GitHub repository. |
| **`CLONE_DIR`** | Optional | Target parent directory for cloning the repository. Defaults to `$HOME` (ephemeral container home directory). | Set to a custom path only if you want to override `$HOME`. |

## Positional Arguments

| Position | Argument | Example | Description |
| :--- | :--- | :--- | :--- |
| **`$1`** | `GIT_NAME` | `"Jane Doe"` | Sets `git config --global user.name`. |
| **`$2`** | `GIT_EMAIL` | `"jane@example.com"` | Sets `git config --global user.email`. |
| **`$3`** | `REPO_URL` | `"https://github.com"` | Clones the repository into `$HOME/<repo-name>`, enters the folder, and runs `flutter pub get`. |

## Troubleshooting

* **`no such file or directory` when running `start.sh`:**
  Make sure there is no backslash (`\`) before `$HOME` in your terminal command. Run `source "$HOME/drive/nomac/start.sh"` rather than `source "\$HOME/drive/nomac/start.sh"`.
* **Commands (`flutter`, `sdkmanager`, `shorebird`) not found after script finishes:**
  Ensure you invoked the script with `source` (or `.`) rather than `bash` or `zsh`. Running a script in a subshell prevents exported `PATH` changes from persisting in your active terminal session.
* **`flutter doctor` warns about missing Chrome:**
  Google Chrome is not installed in headless/disposable macOS containers by default. This warning only affects Flutter Web builds and can be safely ignored for Android and iOS builds.
* **`flutter doctor` reports missing Android SDK or BuildTools versions:**
  If a newer Flutter release requires an updated Android API level (e.g., API 37), install it manually with:
  ```bash
  sdkmanager "platforms;android-37" "build-tools;37.0.0"
  yes | flutter doctor --android-licenses
  ```
* **Git clone fails on private repositories:**
  Verify that your `GH_TOKEN` has the `repo` scope enabled and that `gh auth status` reports an active logged-in session.
* **Copy-pasting `start.sh` corrupts `$` variables:**
  When creating `start.sh` via terminal paste, always wrap `EOF` in single quotes (`cat << 'EOF' > start.sh`) so `zsh` does not expand variables prematurely.

## Contributing

Contributions are welcome! To propose improvements or fixes via Pull Request:

1. **Fork & Clone:** Fork this repository and clone your fork into a fresh disposable macOS container.
2. **Create a Feature Branch:** Branch off `main` using a descriptive name (e.g., `git checkout -b fix/android-sdk-37` or `feat/branch-checkout`).
3. **Follow Script Conventions:**
   * Keep `start.sh` **idempotent** and **zero-footprint**—never store downloaded SDKs, caches, or decoded secrets inside `$HOME/drive`.
   * Avoid `set -e` at the top level so sourcing the script does not close the user's terminal session if a non-critical check fails.
   * Test both **Apple Silicon (`arm64`)** and **Intel (`x86_64`)** paths if modifying architecture-specific logic.
4. **Verify in a Clean Container:** Run `source start.sh` on a brand-new container boot and confirm `flutter doctor`, `shorebird doctor`, `firebase --version`, and `gh auth status` succeed.
5. **Open a Pull Request:** Push your branch, update `README.md` if you added new environment variables or arguments, and submit a PR with a clear summary of your changes and test output.
