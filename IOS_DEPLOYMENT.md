# Local Windows/Linux Sync & iOS/macOS Shorebird Deployment (`nomac`)

This guide covers syncing a **local** Flutter + Shorebird project from a **Windows or Linux** machine to an ephemeral macOS container on `nomac.app`, building a signed `.ipa` (or macOS build), uploading to **TestFlight**, and promoting the validated build to the **App Store**.

---

## Architecture & Workflow Overview

1. **Automated Bootstrap & Real-Time Sync:** Run `scripts/nomac-dev.sh` (Linux/WSL) or `scripts/nomac-dev.ps1` (Windows) from your local project root to start a container, clone/pull `theeomm/nomac` onto `$HOME/drive/nomac`, sync your project to `$HOME/drive/src/<folder>`, provision Flutter/Shorebird via `start.sh`, and open/print the macOS desktop URL.
2. **Code Signing & Shorebird Release:** Generate signing certificates and `ExportOptions.plist` with `nomac sign`, then build with `shorebird release ios`.
3. **TestFlight & Container Teardown:** Upload the `.ipa` via `nomac testflight`, immediately run `nomac stop` to halt per-minute billing while Apple processes the binary, and promote the validated build to the App Store.

---

## Prerequisites

### Local Machine (Windows or Linux)
* **Node.js 20+** and **OpenSSH** (`ssh` available in your terminal/PowerShell).
* **NoMac CLI** installed and authenticated:
  ```bash
  npm install -g @nomac/cli
  nomac login
  ```
* **Shorebird initialized** in your local Flutter project (`shorebird.yaml` present at the root and listed under `assets:` in `pubspec.yaml`).
* **Version bumped** in `pubspec.yaml` (e.g., `version: 1.0.2+3`).

### Cloud & App Store Connect
* An app record created in [App Store Connect](https://apple.com) matching your Bundle ID (`PRODUCT_BUNDLE_IDENTIFIER`).
* Your **App Store Connect API Key** (`.p8`, Key ID, and Issuer ID) configured in the [NoMac Dashboard](https://nomac.app).
* **`SHOREBIRD_TOKEN`** generated via `shorebird login:ci` (or from the [Shorebird Console](https://shorebird.dev)) and stored via `nomac secrets set SHOREBIRD_TOKEN="sb_api_..."` or exported locally.

---

## Step 1: Boot, Sync in Real Time & Bootstrap (`nomac-dev`)

Run the wrapper script for your OS from your **local Flutter project root**. Both scripts automatically:
* Start or reconnect to your project's NoMac container (`nomac start`).
* Clone `https://github.com` into `$HOME/drive/nomac` (or run `git pull --ff-only` if already present).
* Sync your local project to `$HOME/drive/src/<project-folder>` while ignoring `build/`, `.git/`, and `.nomacignore` entries.
* Source `$HOME/drive/nomac/start.sh` to install Flutter, Shorebird, and CLI tools on the ephemeral disk.
* Display/launch the remote macOS desktop URL (`nomac desktop`).

### Option A: Linux / macOS / WSL / Git Bash
```bash
chmod +x /path/to/nomac/scripts/nomac-dev.sh
/path/to/nomac/scripts/nomac-dev.sh "Your Name" "you@example.com" --watch
```

### Option B: Windows (PowerShell)
```powershell
\path\to\nomac\scripts\nomac-dev.ps1 -GitName "Your Name" -GitEmail "you@example.com" -Watch
```

> **Tip:** Leave the `--watch` / `-Watch` terminal open while iterating on code—every local file save streams automatically to `$HOME/drive/src/<project-folder>`. Open a second terminal tab for SSH and release commands.

*(Optional)* Create a `.nomacignore` file in your project root to exclude large local directories from syncing:
```text
.dart_tool/
build/
.idea/
*.log
```

---

## Step 2: Code Signing & Shorebird Release Build

In a second terminal tab from your local project root, open an SSH session into the container (or run commands directly via `nomac exec`):

```bash
nomac ssh
```

Navigate to your synced project directory:

```bash
cd "$HOME/drive/src/(ls "HOME/drive/src" | head -n 1)"
```

### 1. Generate Signing Certificates & `ExportOptions.plist`
Run NoMac's signing helper to register your Bundle ID (if needed), install your distribution certificate and App Store provisioning profile into the ephemeral keychain, and write `ExportOptions.plist`:

```bash
nomac sign
```

### 2. Compile the Shorebird Release (`.ipa` or macOS)
Run `shorebird release` so Shorebird compiles your app with its custom Flutter engine and registers the Dart release baseline:

* **iOS (`.ipa`):**
  ```bash
  shorebird release ios -- --export-options-plist=ExportOptions.plist
  ```
  *Output:* `build/ios/ipa/<YourApp>.ipa`

* **macOS (`.app` / `.pkg`):**
  ```bash
  shorebird release macos
  ```
  *Output:* `build/macos/Build/Products/Release/<YourApp>.app`

Exit the SSH session once the build finishes:

```bash
exit
```

---

## Step 3: Upload to TestFlight & Stop the Container

From your **local terminal**, upload the `.ipa` to TestFlight:

```bash
nomac testflight build/ios/ipa/YourApp.ipa \
  --notes "Release notes for internal testers." \
  --encryption no
```

### Save Container Credits During Apple Processing
Apple takes **5–15 minutes** to process a build before it appears in TestFlight. You do **not** need to keep the macOS container running during processing:

1. Once `nomac testflight` confirms the upload succeeded and prints your upload ID (`tfu_...`), press `Ctrl + C` to detach.
2. Stop the `--watch` terminal (`Ctrl + C`) and destroy the container immediately to stop per-minute billing:
   ```bash
   nomac stop
   ```
3. Check TestFlight processing status for free from your local machine:
   ```bash
   nomac testflight --id tfu_your_upload_id
   ```

---

## Step 4: Promote TestFlight Build to the App Store

Once TestFlight testers validate the build, promote **that exact binary** to production—never rebuild a separate `.ipa` for App Store submission.

### Option A: Promote via CLI (`nomac publish`)
```bash
nomac start
nomac publish build/ios/ipa/YourApp.ipa \
  --whats-new "Bug fixes and performance improvements."
```

1. Review the output for any missing App Store Connect metadata blockers (screenshots, privacy policy URL, age rating, etc.).
2. Re-run with `--confirm` to submit to **App Review**, then shut down the container:
   ```bash
   nomac publish build/ios/ipa/YourApp.ipa \
     --whats-new "Bug fixes and performance improvements." \
     --confirm
   nomac stop
   ```

### Option B: Promote via App Store Connect Web UI (Zero Container Cost)
If you already ran `nomac stop` after uploading to TestFlight:

1. Open [App Store Connect](https://apple.com) → **My Apps** → select your app.
2. Under the **Distribution** tab, select your iOS version (or click **+ Version or Platform**).
3. Complete the required store listing fields (screenshots, description, support URL, **What's New**) and **App Review Information**.
4. In the **Build** section, click **Add Build** and select the validated TestFlight build.
5. Click **Add for Review** → **Submit to App Review**.

---

## Step 5: Shipping Over-the-Air (OTA) Dart Patches Later

To ship a Dart-only fix to users on your live version without waiting for Apple App Review:

1. Boot and sync your updated code using the wrapper script (without `--watch`):
   ```bash
   /path/to/nomac/scripts/nomac-dev.sh "Your Name" "you@example.com"
   ```
2. Push the Shorebird patch and shut down the container immediately:
   ```bash
   nomac exec --wait 600 -- zsh -lc 'cd "\$HOME/drive/src/"* && shorebird patch ios --track=stable'
   nomac stop
   ```

> **Reminder:** `shorebird patch` only supports Dart code changes. Native Swift/Objective-C edits, `Info.plist` updates, asset changes, or new native plugins require repeating **Steps 1–4** with an incremented build number.
