#!/usr/bin/env zsh

GIT_NAME="$1"
GIT_EMAIL="$2"
REPO_URL="${3:-$REPO_URL}"
CLONE_DIR="${CLONE_DIR:-$HOME}"

# Ensure Homebrew is loaded in PATH
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"

# 1. Install JDK 21, GitHub CLI, Firebase CLI, Flutter & Android Command-Line Tools via Homebrew
echo "Installing core toolchains via Homebrew..."
HOMEBREW_NO_AUTO_UPDATE=1 brew install openjdk@21 gh firebase-cli
HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask flutter android-commandlinetools

# 2. Install Shorebird CLI (Direct Git Clone + Bootstrap)
echo "Installing Shorebird CLI..."
rm -rf "$HOME/.shorebird"
git clone -b stable https://github.com/shorebirdtech/shorebird.git "$HOME/.shorebird"
"$HOME/.shorebird/bin/shorebird" --version

# 3. Configure Environment Variables & PATH
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$(brew --prefix)/share/android-commandlinetools"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PUB_CACHE="$HOME/.pub-cache"

export PATH="$JAVA_HOME/bin:$HOME/.shorebird/bin:$HOME/.pub-cache/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# Persist exports in ~/.zshrc for new terminal tabs
if ! grep -q "ANDROID_SDK_ROOT" "$HOME/.zshrc" 2>/dev/null; then
  cat << EOF >> "$HOME/.zshrc"
eval "\$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
export JAVA_HOME="$JAVA_HOME"
export ANDROID_HOME="$ANDROID_HOME"
export ANDROID_SDK_ROOT="\$ANDROID_HOME"
export PUB_CACHE="\$HOME/.pub-cache"
export PATH="\$JAVA_HOME/bin:\$HOME/.shorebird/bin:\$HOME/.pub-cache/bin:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$PATH"
EOF
fi

# 4. Install Android SDK 36 Packages & Accept Licenses
echo "Installing Android SDK 36 packages..."
yes | sdkmanager --licenses >/dev/null 2>&1 || true
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"

# 5. Configure Flutter & Activate FlutterFire CLI
echo "Configuring Flutter and activating FlutterFire CLI..."
flutter config --android-sdk "$ANDROID_HOME"
dart pub global activate flutterfire_cli

# 6. Configure Git & Authenticate GitHub CLI
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
  echo "Configuring Git identity for $GIT_NAME <$GIT_EMAIL>..."
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
fi

if [ -z "$GH_TOKEN" ]; then
  gh auth login -p https -w
fi
gh auth setup-git

# 7. Authenticate Shorebird & Firebase
if [ -n "$SHOREBIRD_TOKEN" ]; then
  export SHOREBIRD_TOKEN
  echo "Shorebird authenticated via SHOREBIRD_TOKEN."
  shorebird doctor || true
fi

if [ -n "$FIREBASE_SERVICE_ACCOUNT_BASE64" ]; then
  mkdir -p /tmp/dev-tools
  echo "$FIREBASE_SERVICE_ACCOUNT_BASE64" | base64 --decode > /tmp/dev-tools/firebase-sa.json
  export GOOGLE_APPLICATION_CREDENTIALS="/tmp/dev-tools/firebase-sa.json"
  echo "Firebase authenticated via GOOGLE_APPLICATION_CREDENTIALS."
elif [ -n "$FIREBASE_TOKEN" ]; then
  export FIREBASE_TOKEN
  echo "Firebase authenticated via FIREBASE_TOKEN."
fi

# 8. Auto-Clone Repository into $HOME & Install Dependencies
if [ -n "$REPO_URL" ]; then
  REPO_NAME=$(basename "$REPO_URL" .git)
  TARGET_PATH="$CLONE_DIR/$REPO_NAME"
  echo "Cloning repository into $TARGET_PATH..."

  if [ -d "$TARGET_PATH/.git" ]; then
    echo "Repository already exists at $TARGET_PATH; pulling latest changes..."
    cd "$TARGET_PATH" && git pull
  else
    git clone "$REPO_URL" "$TARGET_PATH"
    cd "$TARGET_PATH"
  fi

  if [ -f "pubspec.yaml" ]; then
    echo "Running flutter pub get..."
    flutter pub get
  fi
fi

echo "Setup complete!"
