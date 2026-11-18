# Nomac | Flutter & Android Development Setup

A zero-footprint bootstrap script (`setup.sh`) designed for disposable macOS containers. Only `setup.sh` lives on persistent storage; all SDKs, toolchains, and credentials are downloaded and configured inside `/tmp/dev-tools` on each container startup.

## Installed Tools

The script automatically detects Apple Silicon (`arm64`) or Intel (`x86_64`) and installs:
* **Eclipse Temurin JDK 21** (Portable macOS build)
* **Android SDK Command-Line Tools** (`platform-tools`, `platforms;android-35`, `build-tools;35.0.0`)
* **Flutter SDK** (Latest stable release)
* **Shorebird CLI**
* **Firebase CLI** (Standalone binary, no Node.js required)
* **FlutterFire CLI** (Activated via Dart Pub)
* **GitHub CLI (`gh`)** (Configured as Git credential helper via `gh auth setup-git`)

## Usage

### 1. Interactive Setup (Manual Login)
Source the script and pass your Git `user.name` and `user.email` as positional arguments. If authentication tokens are omitted, interactive browser login prompts will run where supported:

```bash
source "\$HOME/drive/setup.sh" "Your Name" "you@example.com"
```

> **Note:** Always run with `source` (or `.`) so exported `PATH` and environment variables apply immediately to your active terminal session.

### 2. Headless / Non-Interactive Setup (With Tokens)
Pass your authentication tokens as environment variables before sourcing `setup.sh`:

```bash
GH_TOKEN="ghp_your_github_token" \
SHOREBIRD_TOKEN="sb_api_your_shorebird_token" \
FIREBASE_SERVICE_ACCOUNT_BASE64="\$(base64 -i path/to/service-account.json)" \
source "\$HOME/drive/setup.sh" "Your Name" "you@example.com"
```

## Environment Variables Reference

| Variable | Required | Description | How to Obtain |
| :--- | :--- | :--- | :--- |
| **`GH_TOKEN`** | Optional | Personal Access Token for GitHub CLI (`gh`) and `gh auth setup-git`. Falls back to interactive `gh auth login` if unset. | GitHub **Settings -> Developer settings -> Personal access tokens** (needs `repo` and `read:org` scopes). |
| **`SHOREBIRD_TOKEN`** | Optional | API token for headless Shorebird releases and patches. Falls back to manual `shorebird login` if unset. | Run `shorebird login:ci` locally or generate an API key in the **Shorebird Console**. |
| **`FIREBASE_SERVICE_ACCOUNT_BASE64`** | Optional | Base64-encoded Firebase Admin/Service Account JSON file. Decoded to `/tmp/dev-tools/firebase-sa.json` and exported as `GOOGLE_APPLICATION_CREDENTIALS`. *(Recommended over `FIREBASE_TOKEN`)*. | Firebase Console **Project Settings -> Service accounts -> Generate new private key**, then encode with `base64 -i key.json`. |
| **`FIREBASE_TOKEN`** | Optional | Legacy CI token for Firebase CLI. Used only if `FIREBASE_SERVICE_ACCOUNT_BASE64` is not provided. | Run `firebase login:ci` on an authenticated machine. |

## Positional Arguments

| Position | Argument | Example | Description |
| :--- | :--- | :--- | :--- |
| **`$1`** | `GIT_NAME` | `"Jane Doe"` | Sets `git config --global user.name`. |
| **`$2`** | `GIT_EMAIL` | `"jane@example.com"` | Sets `git config --global user.email`. |

