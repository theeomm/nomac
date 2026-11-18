#!/usr/bin/env bash
set -e

GIT_NAME="$1"
GIT_EMAIL="$2"

export EPHEMERAL_DIR="/tmp/dev-tools"
export BIN_DIR="$EPHEMERAL_DIR/bin"
mkdir -p "$EPHEMERAL_DIR/jdk" \
         "$EPHEMERAL_DIR/android-sdk/cmdline-tools" \
         "$BIN_DIR"

# 1. Detect CPU Architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  GH_JDK_PATTERN="OpenJDK21U-jdk_aarch64_mac_hotspot_.*\\.tar\\.gz$"
  SDK_ARCH="mac_arm64"
  FLUTTER_ARCH="arm64"
  GH_ARCH="arm64"
else
  GH_JDK_PATTERN="OpenJDK21U-jdk_x64_mac_hotspot_.*\\.tar\\.gz$"
  SDK_ARCH="mac_x86_64"
  FLUTTER_ARCH="x64"
  GH_ARCH="amd64"
fi

# 2. Download Portable JDK 21 directly from GitHub Releases
echo "Fetching JDK 21 release URL from GitHub ($ARCH)..."
rm -f /tmp/jdk.tar.gz

JDK_URL=$(curl -fsSL "https://github.com" | python3 -c "
import sys, json, re
assets = json.load(sys.stdin).get('assets', [])
pattern = re.compile(r'$GH_JDK_PATTERN')
print(next((a['browser_download_url'] for a in assets if pattern.search(a['name'])), ''))
")

if [ -z "$JDK_URL" ]; then
  echo "ERROR: Could not fetch JDK URL from GitHub API. Check internet/DNS or GitHub rate limits."
  exit 1
fi

echo "Downloading JDK 21 from: $JDK_URL"
curl -fSL --retry 3 --retry-delay 2 "$JDK_URL" -o /tmp/jdk.tar.gz

if ! file /tmp/jdk.tar.gz | grep -qi "gzip"; then
  echo "ERROR: Downloaded file is not a valid gzip archive. File info:"
  file /tmp/jdk.tar.gz
  head -c 300 /tmp/jdk.tar.gz
  exit 1
fi

tar -xzf /tmp/jdk.tar.gz -C "$EPHEMERAL_DIR/jdk" --strip-components=1
rm -f /tmp/jdk.tar.gz


# 3. Download Latest Android Command-Line Tools
echo "Downloading Android Command-Line Tools ($SDK_ARCH)..."
CMDLINE_URL=$(curl -fsSL https://android.com | grep -o "https://google.com[0-9]*_latest.zip" | head -n 1)
CMDLINE_URL=${CMDLINE_URL:-"https://google.com"}

curl -fL --retry 3 --retry-delay 2 "$CMDLINE_URL" -o /tmp/cmdline-tools.zip
unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-extract
mv /tmp/cmdline-extract/cmdline-tools "$EPHEMERAL_DIR/android-sdk/cmdline-tools/latest"
rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-extract

# 4. Download Latest Stable Flutter SDK
echo "Downloading latest stable Flutter SDK ($FLUTTER_ARCH)..."
FLUTTER_REL_PATH=$(curl -fsSL "https://googleapis.com" | python3 -c "import sys, json; data = json.load(sys.stdin); stable = data['current_release']['stable']; print(next(r['archive'] for r in data['releases'] if r['hash'] == stable and r.get('dart_sdk_arch', 'x64') == '$FLUTTER_ARCH'))")

curl -fL --retry 3 --retry-delay 2 "https://googleapis.com" -o /tmp/flutter.zip
unzip -q /tmp/flutter.zip -d "$EPHEMERAL_DIR"
rm -f /tmp/flutter.zip

# 5. Download Shorebird CLI
echo "Downloading Shorebird CLI..."
curl -fsSL https://shorebird.dev | bash

# 6. Download Standalone Firebase CLI Binary
echo "Downloading standalone Firebase CLI..."
FIREBASE_VERSION=$(curl -fsSL https://npmjs.org | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])")
FIREBASE_URL="https://firebase.tools"
curl -fL --retry 3 --retry-delay 2 "$FIREBASE_URL" -o "$BIN_DIR/firebase"
chmod +x "$BIN_DIR/firebase"

# 7. Download Latest GitHub CLI (gh) Binary
echo "Downloading GitHub CLI ($GH_ARCH)..."
GH_URL=$(curl -fsSL "https://github.com" | python3 -c "import sys, json; assets = json.load(sys.stdin)['assets']; print(next(a['browser_download_url'] for a in assets if 'macOS_$GH_ARCH.zip' in a['name']))")
curl -fL --retry 3 --retry-delay 2 "$GH_URL" -o /tmp/gh.zip
unzip -q /tmp/gh.zip -d /tmp/gh-extract
mv /tmp/gh-extract/*/bin/gh "$BIN_DIR/gh"
chmod +x "$BIN_DIR/gh"
rm -rf /tmp/gh.zip /tmp/gh-extract

# 8. Export Environment Variables & Inject Paths
export JAVA_HOME="$EPHEMERAL_DIR/jdk/Contents/Home"
export ANDROID_HOME="$EPHEMERAL_DIR/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export FLUTTER_ROOT="$EPHEMERAL_DIR/flutter"
export PUB_CACHE="$HOME/.pub-cache"

export PATH="$JAVA_HOME/bin:$FLUTTER_ROOT/bin:$HOME/.shorebird/bin:$HOME/.pub-cache/bin:$BIN_DIR:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# Persist exports in ~/.zshrc for new terminal tabs
if ! grep -q "EPHEMERAL_DIR=\"/tmp/dev-tools\"" "$HOME/.zshrc" 2>/dev/null; then
  cat << 'EOF' >> "$HOME/.zshrc"
export EPHEMERAL_DIR="/tmp/dev-tools"
export BIN_DIR="$EPHEMERAL_DIR/bin"
export JAVA_HOME="$EPHEMERAL_DIR/jdk/Contents/Home"
export ANDROID_HOME="$EPHEMERAL_DIR/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export FLUTTER_ROOT="$EPHEMERAL_DIR/flutter"
export PUB_CACHE="$HOME/.pub-cache"
export PATH="$JAVA_HOME/bin:$FLUTTER_ROOT/bin:$HOME/.shorebird/bin:$HOME/.pub-cache/bin:$BIN_DIR:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
EOF
fi

# 9. Install Android SDK Packages & Accept Licenses
echo "Installing Android SDK packages..."
yes | sdkmanager --licenses >/dev/null 2>&1 || true
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"

# 10. Configure Flutter & Activate FlutterFire CLI
echo "Configuring Flutter and activating FlutterFire CLI..."
flutter config --android-sdk "$ANDROID_HOME"
dart pub global activate flutterfire_cli

# 11. Configure Git & Authenticate GitHub CLI
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
  echo "Configuring Git identity for $GIT_NAME <$GIT_EMAIL>..."
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
else
  echo "Skipping Git user.name/user.email (pass them as arguments: source setup.sh \"Name\" \"email\")."
fi

if [ -n "$GH_TOKEN" ]; then
  echo "Authenticating GitHub CLI via GH_TOKEN..."
else
  echo "Starting interactive GitHub CLI authentication..."
  gh auth login -p https -w
fi
gh auth setup-git

# 12. Authenticate Shorebird & Firebase
if [ -n "$SHOREBIRD_TOKEN" ]; then
  export SHOREBIRD_TOKEN
  echo "Shorebird authenticated via SHOREBIRD_TOKEN."
  shorebird auth status || true
else
  echo "SHOREBIRD_TOKEN not set; run 'shorebird login' manually if needed."
fi

if [ -n "$FIREBASE_SERVICE_ACCOUNT_BASE64" ]; then
  echo "$FIREBASE_SERVICE_ACCOUNT_BASE64" | base64 --decode > "$EPHEMERAL_DIR/firebase-sa.json"
  export GOOGLE_APPLICATION_CREDENTIALS="$EPHEMERAL_DIR/firebase-sa.json"
  echo "Firebase authenticated via GOOGLE_APPLICATION_CREDENTIALS."
elif [ -n "$FIREBASE_TOKEN" ]; then
  export FIREBASE_TOKEN
  echo "Firebase authenticated via FIREBASE_TOKEN."
else
  echo "No Firebase token provided; run 'firebase login' manually if needed."
fi

echo "Setup complete!"
