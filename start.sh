#!/usr/bin/env bash
# Ephemeral macOS Flutter Development Environment Setup (nomac)
# Zero-footprint: installs all SDKs and tools onto the container's ephemeral disk.

# Do not use `set -e` so sourcing this script never kills the user's SSH session on minor warnings.

GIT_NAME="${1:-}"
GIT_EMAIL="${2:-}"
TARGET_ARG="${3:-}"

# Support passing either a Git URL or a local synced directory path as $3
if [[ -n "$TARGET_ARG" ]]; then
  if [[ -d "$TARGET_ARG" ]]; then
    LOCAL_DIR="$TARGET_ARG"
  else
    REPO_URL="$TARGET_ARG"
  fi
fi

CLONE_DIR="${CLONE_DIR:-$HOME}"
TOOLS_DIR="/tmp/dev-tools"
mkdir -p "$TOOLS_DIR"

echo "==> Configuring Git..."
[[ -n "$GIT_NAME" ]] && git config --global user.name "$GIT_NAME"
[[ -n "$GIT_EMAIL" ]] && git config --global user.email "$GIT_EMAIL"

echo "==> Installing Homebrew packages (OpenJDK 21, Android CLI, Flutter, Firebase, GitHub CLI)..."
export HOMEBREW_NO_AUTO_UPDATE=1
brew install --cask flutter 2>/dev/null || brew upgrade --cask flutter 2>/dev/null || true
brew install openjdk@21 android-commandlinetools firebase-cli gh 2>/dev/null || true

# Configure Java & Android SDK paths
if [[ -d "/opt/homebrew/opt/openjdk@21" ]]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
else
  export JAVA_HOME="/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  export ANDROID_HOME="/usr/local/share/android-commandlinetools"
fi

export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$HOME/.pub-cache/bin:$PATH"

echo "==> Provisioning Android SDK components..."
if command -v sdkmanager >/dev/null 2>&1; then
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" >/dev/null 2>&1 || true
fi

echo "==> Installing Shorebird CLI..."
if [[ ! -d "$TOOLS_DIR/shorebird" ]]; then
  git clone https://github.com/shorebirdtech/shorebird -b stable "$TOOLS_DIR/shorebird" >/dev/null 2>&1
fi
export PATH="$TOOLS_DIR/shorebird/bin:$PATH"
shorebird --version >/dev/null 2>&1 || true

echo "==> Activating FlutterFire CLI..."
dart pub global activate flutterfire_cli >/dev/null 2>&1 || true

echo "==> Authenticating CLI services..."
if [[ -n "${GH_TOKEN:-}" ]]; then
  echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null && gh auth setup-git
fi

if [[ -n "${FIREBASE_SERVICE_ACCOUNT_BASE64:-}" ]]; then
  echo "$FIREBASE_SERVICE_ACCOUNT_BASE64" | base64 -d > "$TOOLS_DIR/firebase-sa.json"
  export GOOGLE_APPLICATION_CREDENTIALS="$TOOLS_DIR/firebase-sa.json"
fi

if [[ -n "${SHOREBIRD_TOKEN:-}" ]]; then
  export SHOREBIRD_TOKEN
  echo "SHOREBIRD_TOKEN exported for headless releases/patches."
fi

# Workspace resolution: Local synced directory vs. Git clone
if [[ -n "${LOCAL_DIR:-}" && -d "$LOCAL_DIR" ]]; then
  echo "==> Entering local synced project: $LOCAL_DIR"
  cd "$LOCAL_DIR" || return
  [[ -f "pubspec.yaml" ]] && flutter pub get
elif [[ -n "${REPO_URL:-}" ]]; then
  REPO_NAME="$(basename "$REPO_URL" .git)"
  DEST_PATH="$CLONE_DIR/$REPO_NAME"
  echo "==> Cloning $REPO_URL into $DEST_PATH..."
  git clone "$REPO_URL" "$DEST_PATH"
  cd "$DEST_PATH" || return
  [[ -f "pubspec.yaml" ]] && flutter pub get
fi

echo "==> Ephemeral macOS Flutter environment ready!"
