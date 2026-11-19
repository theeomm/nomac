#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Local-to-NoMac Flutter + Shorebird Wrapper
# Usage: ./nomac-dev.sh "Your Name" "you@example.com" [--watch]
# ==============================================================================

GIT_NAME="${1:-}"
GIT_EMAIL="${2:-}"
WATCH_FLAG="${3:-}"

if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" ]]; then
  echo "Usage: $0 \"Your Name\" \"you@example.com\" [--watch]"
  exit 1
fi

PROJECT_FOLDER="$(basename "$PWD")"
REMOTE_PROJECT_DIR="\$HOME/drive/src/${PROJECT_FOLDER}"
SETUP_REPO="https://github.com"

echo "==> 1. Starting or reconnecting to NoMac instance..."
nomac start

echo "==> 2. Ensuring theeomm/nomac setup repo is cloned & up-to-date on ~/drive/nomac..."
nomac exec --wait 120 -- bash -lc "
  mkdir -p \"\$HOME/drive\"
  if [ ! -d \"\$HOME/drive/nomac/.git\" ]; then
    echo 'Cloning theeomm/nomac into ~/drive/nomac...'
    git clone '$SETUP_REPO' \"\$HOME/drive/nomac\"
  else
    echo 'Updating existing ~/drive/nomac repository...'
    git -C \"\$HOME/drive/nomac\" pull --ff-only
  fi
"

echo "==> 3. Syncing local project ($PROJECT_FOLDER) to ~/drive/src/$PROJECT_FOLDER..."
nomac sync . --delete

echo "==> 4. Provisioning ephemeral Flutter & Shorebird environment..."
# Pass tokens if exported locally (e.g., SHOREBIRD_TOKEN, GH_TOKEN, FIREBASE_SERVICE_ACCOUNT_BASE64)
ENV_PREFIX=""
[[ -n "${SHOREBIRD_TOKEN:-}" ]] && ENV_PREFIX+="SHOREBIRD_TOKEN='$SHOREBIRD_TOKEN' "
[[ -n "${GH_TOKEN:-}" ]] && ENV_PREFIX+="GH_TOKEN='$GH_TOKEN' "
[[ -n "${FIREBASE_SERVICE_ACCOUNT_BASE64:-}" ]] && ENV_PREFIX+="FIREBASE_SERVICE_ACCOUNT_BASE64='$FIREBASE_SERVICE_ACCOUNT_BASE64' "

nomac exec --wait 900 -- zsh -lc "
  ${ENV_PREFIX}source \"\$HOME/drive/nomac/start.sh\" \"$GIT_NAME\" \"$GIT_EMAIL\" \"$REMOTE_PROJECT_DIR\"
"

echo "==> 5. Desktop & Session Access:"
# Attempt to print/open the desktop URL without failing if running in a headless terminal
nomac desktop 2>&1 || true
echo "Dashboard & active sessions: https://nomac.app"

if [[ "$WATCH_FLAG" == "--watch" ]]; then
  echo "==> 6. Starting real-time file sync (Ctrl+C to stop watching)..."
  nomac sync . --watch --delete
else
  echo "==> Done! Run 'nomac ssh' to enter the shell or 'nomac stop' when finished."
fi
