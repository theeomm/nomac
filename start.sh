#!/usr/bin/env zsh
# Persistent macOS Flutter Development Environment Setup for NoMac
# Usage: source "$HOME/drive/nomac/start.sh" "Your Name" "you@example.com" "https://github.com"

GIT_NAME="${1:-}"
GIT_EMAIL="${2:-}"
TARGET_REPO="${3:-$REPO_URL}"

# 1. Persistent Directories in ~/drive/tools
TOOLS_ROOT="$HOME/drive/tools"
BREW_PREFIX="$TOOLS_ROOT/homebrew"
ANDROID_ROOT="$TOOLS_ROOT/android-sdk"
SHOREBIRD_DIR="$TOOLS_ROOT/shorebird"
PUB_CACHE_DIR="$TOOLS_ROOT/pub-cache"
GRADLE_CACHE_DIR="$TOOLS_ROOT/gradle"
COCOAPODS_CACHE_DIR="$TOOLS_ROOT/cocoapods"
CACHE_DIR="$TOOLS_ROOT/caches"

mkdir -p "$BREW_PREFIX" "$ANDROID_ROOT" "$PUB_CACHE_DIR" "$GRADLE_CACHE_DIR" "$COCOAPODS_CACHE_DIR" "$CACHE_DIR"

# 2. Export Persistent Environment Variables
export HOMEBREW_CACHE="$CACHE_DIR/homebrew"
export HOMEBREW_NO_AUTO_UPDATE=1
export PUB_CACHE="$PUB_CACHE_DIR"
export GRADLE_USER_HOME="$GRADLE_CACHE_DIR"
export CP_HOME_DIR="$COCOAPODS_CACHE_DIR"
export ANDROID_HOME="$ANDROID_ROOT"
export ANDROID_SDK_ROOT="$ANDROID_ROOT"

# Symlink standard home cache paths to ~/drive/tools
rm -rf "$HOME/.pub-cache" "$HOME/.gradle"
ln -sfn "$PUB_CACHE_DIR" "$HOME/.pub-cache"
ln -sfn "$GRADLE_CACHE_DIR" "$HOME/.gradle"

mkdir -p "$HOME/Library/Caches"
rm -rf "$HOME/Library/Caches/CocoaPods"
ln -sfn "$COCOAPODS_CACHE_DIR" "$HOME/Library/Caches/CocoaPods"

# 3. Install or Load Persistent Homebrew in ~/drive/tools/homebrew
if [[ ! -x "$BREW_PREFIX/bin/brew" ]]; then
  echo "Installing persistent Homebrew into $BREW_PREFIX..."
  git clone --depth=1 https://github.com/Homebrew/brew "$BREW_PREFIX"
fi
eval "$("$BREW_PREFIX/bin/brew" shellenv)"

# 4. Install Core Toolchains (Skipped if already persisted)
BREW_PACKAGES=(
  "openjdk@21"
  "android-commandlinetools"
  "flutter"
  "firebase-cli"
  "gh"
)

for pkg in "${BREW_PACKAGES[@]}"; do
  if ! brew list "$pkg" &>/dev/null; then
    echo "Installing $pkg..."
    brew install "$pkg"
  else
    echo "$pkg already persisted in $BREW_PREFIX."
  fi
done

# Configure OpenJDK 21 & Android SDK Paths
export JAVA_HOME="$BREW_PREFIX/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$BREW_PREFIX/share/android-commandlinetools/cmdline-tools/latest/bin:$PATH"

if [[ ! -d "$ANDROID_HOME/platforms/android-36" ]]; then
  echo "Installing Android SDK components..."
  yes | sdkmanager --sdk_root="$ANDROID_HOME" "platform-tools" "platforms;android-36" "build-tools;36.0.0" >/dev/null
  yes | flutter doctor --android-licenses >/dev/null
fi

# 5. Clone & Bootstrap Shorebird in ~/drive/tools/shorebird
if [[ ! -d "$SHOREBIRD_DIR/.git" ]]; then
  echo "Cloning Shorebird into $SHOREBIRD_DIR..."
  git clone https://github.com/shorebirdtech/shorebird -b stable "$SHOREBIRD_DIR"
fi

export PATH="$SHOREBIRD_DIR/bin:$PUB_CACHE_DIR/bin:$PATH"
if [[ ! -f "$SHOREBIRD_DIR/bin/cache/shorebird.snapshot" ]]; then
  echo "Bootstrapping Shorebird CLI..."
  shorebird --version
fi

# 6. Activate FlutterFire CLI (Cached in ~/drive/tools/pub-cache)
if ! command -v flutterfire &>/dev/null; then
  echo "Activating FlutterFire CLI..."
  dart pub global activate flutterfire_cli
fi

# 7. Configure Git & Authentication (Ephemeral for security)
[[ -n "$GIT_NAME" ]] && git config --global user.name "$GIT_NAME"
[[ -n "$GIT_EMAIL" ]] && git config --global user.email "$GIT_EMAIL"

if [[ -n "$GH_TOKEN" ]]; then
  gh auth setup-git
elif ! gh auth status &>/dev/null; then
  gh auth login
  gh auth setup-git
fi

if [[ -n "$FIREBASE_SERVICE_ACCOUNT_BASE64" ]]; then
  mkdir -p /tmp/dev-tools
  echo "$FIREBASE_SERVICE_ACCOUNT_BASE64" | base64 --decode > /tmp/dev-tools/firebase-sa.json
  export GOOGLE_APPLICATION_CREDENTIALS="/tmp/dev-tools/firebase-sa.json"
fi

# 8. Clone or Enter Project Repository
if [[ -n "$TARGET_REPO" ]]; then
  if [[ -d "$TARGET_REPO" ]]; then
    cd "$TARGET_REPO" || return
  else
    DEST_DIR="${CLONE_DIR:-$HOME}/$(basename "$TARGET_REPO" .git)"
    [[ ! -d "$DEST_DIR" ]] && git clone "$TARGET_REPO" "$DEST_DIR"
    cd "$DEST_DIR" || return
  fi
  [[ -f "pubspec.yaml" ]] && flutter pub get
fi

echo "Persistent environment ready in $TOOLS_ROOT."
