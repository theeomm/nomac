#!/usr/bin/env zsh

GIT_NAME="$1"
GIT_EMAIL="$2"

export EPHEMERAL_DIR="/tmp/dev-tools"
export BIN_DIR="$EPHEMERAL_DIR/bin"
mkdir -p "$EPHEMERAL_DIR/android-sdk/cmdline-tools" "$BIN_DIR"

# Ensure Homebrew is in PATH
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"

# 1. Install OpenJDK 21 & GitHub CLI via Homebrew (already present on your container)
echo "Installing OpenJDK 21 and GitHub CLI via Homebrew..."
HOMEBREW_NO_AUTO_UPDATE=1 brew install openjdk@21 gh

export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"

# 2. Detect CPU Architecture for SDKs
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  SDK_ARCH="mac_arm64"
  FLUTTER_ARCH="arm64"
else
  SDK_ARCH="mac_x86_64"
  FLUTTER_ARCH="x64"
fi

# 3. Download Latest Android Command-Line Tools
echo "Downloading Android Command-Line Tools ($SDK_ARCH)..."
CMDLINE_URL=$(curl -fsSL https://android.com | grep -o "https://google.com[0-9]*_latest.zip" | head -n 1)
CMDLINE_URL=${CMDLINE_URL:-"https://google.com"}

curl -fSL --retry 3 "$CMDLINE_URL" -o /tmp/cmdline-tools.zip
unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-extract
mv /tmp/cmdline-extract/cmdline-tools "$EPHEMERAL_DIR/android-sdk/cmdline-tools/latest"
rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-extract

# 4. Download Latest Stable Flutter SDK
echo "Downloading latest stable Flutter SDK ($FLUTTER_ARCH)..."
FLUTTER_REL_PATH=$(curl -fsSL "https://googleapis.com" | python3 -c "import sys, json; data = json.load(sys.stdin); stable = data['current_release']['stable']; print(next(r['archive'] for r in data['releases'] if r['hash'] == stable and r.get('dart_sdk_arch', 'x64') == '$FLUTTER_ARCH'))")

curl -fSL --retry 3 "https://googleapis.com" -o /tmp/flutter.zip
unzip -q /tmp/flutter.zip -d "$EPHEMERAL_DIR"
rm -f /tmp/flutter.zip

# 5. Download Shorebird CLI
echo "Downloading Shorebird CLI..."
curl -fsSL https://shorebird.dev | bash

# 6. Download Standalone Firebase CLI Binary
echo "Downloading standalone Firebase CLI..."
FIREBASE_VERSION=$(curl -fsSL https://npmjs.org | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])")
curl -fSL --retry 3 "https://firebase.tools" -o "$BIN_DIR/firebase"
chmod +x "$BIN_DIR/firebase"

# 7. Export Environment Variables & Inject Paths
export ANDROID_HOME="$EPHEMERAL_DIR/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export FLUTTER_ROOT="$EPHEMERAL_DIR/flutter"
export PUB_CACHE="$HOME/.pub-cache"

export PATH="$JAVA_HOME/bin:$FLUTTER_ROOT/bin:$HOME/.shorebird/bin:$HOME/.pub-cache/bin:$BIN_DIR:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# Persist exports in ~/.zshrc for new terminal tabs
if ! grep -q "EPHEMERAL_DIR=\"/tmp/dev-tools\"" "$HOME/.zshrc" 2>/dev/null; then
  cat << EOF >> "$HOME/.zshrc"
export EPHEMERAL_DIR="/tmp/dev-tools"
export BIN_DIR="$EPHEMERAL_DIR/bin"
export JAVA_HOME="$JAVA_HOME"
export ANDROID_HOME="$EPHEMERAL_DIR/android-sdk"
export ANDROID_SDK_ROOT="\$ANDROID_HOME"
export FLUTTER_ROOT="$EPHEMERAL_DIR/flutter"
export PUB_CACHE="\$HOME/.pub-cache"
export PATH="\$JAVA_HOME/bin:\$FLUTTER_ROOT/bin:\$HOME/.shorebird/bin:\$HOME/.pub-cache/bin:\$BIN_DIR:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$PATH"
EOF
fi

# 8. Install Android SDK Packages & Accept Licenses
echo "Installing Android SDK packages..."
yes | sdkmanager --licenses >/dev/null 2>&1 || true
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"

# 9. Configure Flutter & Activate FlutterFire CLI
echo "Configuring Flutter and activating FlutterFire CLI..."
flutter config --android-sdk "$ANDROID_HOME"
dart pub global activate flutterfire_cli

# 10. Configure Git & Authenticate GitHub CLI
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
fi

if [ -z "$GH_TOKEN" ]; then
  gh auth login -p https -w
fi
gh auth setup-git

# 11. Authenticate Shorebird & Firebase
if [ -n "$SHOREBIRD_TOKEN" ]; then
  export SHOREBIRD_TOKEN
  shorebird auth status || true
fi

if [ -n "$FIREBASE_SERVICE_ACCOUNT_BASE64" ]; then
  echo "$FIREBASE_SERVICE_ACCOUNT_BASE64" | base64 --decode > "$EPHEMERAL_DIR/firebase-sa.json"
  export GOOGLE_APPLICATION_CREDENTIALS="$EPHEMERAL_DIR/firebase-sa.json"
elif [ -n "$FIREBASE_TOKEN" ]; then
  export FIREBASE_TOKEN
fi

echo "Setup complete!"
