#!/usr/bin/env bash
# create-server-bare-repo.sh
#
# Creates a bare Git repository on your Incus server. Used both for
# backup mirrors of public repos and for canonical storage of sensitive repos.
#
# Usage: ./create-server-bare-repo.sh <repo-name>

set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────
SERVER_HOST="${SERVER_HOST:-yourserver}"
SERVER_GIT_PATH="${SERVER_GIT_PATH:-/var/git}"
# ───────────────────────────────────────────────────────────────────────────

REPO_NAME="${1:-}"

if [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <repo-name>"
    exit 1
fi

# Strip .git suffix if present, then append it once (bare repos conventionally end in .git)
REPO_NAME="${REPO_NAME%.git}"

# The name is interpolated into a shell command on the server — keep it strict.
case "$REPO_NAME" in
    *[!A-Za-z0-9._-]*|.*)
        echo "Error: repo name must contain only letters, digits, '.', '_', '-' and not start with '.'"
        exit 1 ;;
esac
REMOTE_PATH="$SERVER_GIT_PATH/$REPO_NAME.git"

echo "→ Creating bare repo on $SERVER_HOST at $REMOTE_PATH"

ssh "$SERVER_HOST" bash <<EOF
set -e
if [ -d "$REMOTE_PATH" ]; then
    echo "Error: $REMOTE_PATH already exists on server"
    exit 1
fi
mkdir -p "$REMOTE_PATH"
cd "$REMOTE_PATH"
git init --bare -q
echo "✓ Bare repo created at $REMOTE_PATH"
EOF

echo ""
echo "To use as a remote from a local clone:"
echo "  git remote add server $SERVER_HOST:$REMOTE_PATH"
echo ""
echo "Or as a push destination on origin:"
echo "  git remote set-url --add --push origin $SERVER_HOST:$REMOTE_PATH"
