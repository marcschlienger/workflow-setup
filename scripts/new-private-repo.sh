#!/usr/bin/env bash
# new-private-repo.sh
#
# Creates a new repository whose canonical (and only) remote is your
# private server bare repo. Nothing on commercial hosts.
#
# For material sensitive enough that you don't want it on GitHub/GitLab
# even in private repos.
#
# Usage: ./new-private-repo.sh <repo-name>

set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────
SERVER_HOST="${SERVER_HOST:-yourserver}"
SERVER_GIT_PATH="${SERVER_GIT_PATH:-/var/git}"
CODE_DIR="${CODE_DIR:-$HOME/code}"
# ───────────────────────────────────────────────────────────────────────────

REPO_NAME="${1:-}"

if [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <repo-name>"
    exit 1
fi

case "$REPO_NAME" in
    *[!A-Za-z0-9._-]*|.*)
        echo "Error: repo name must contain only letters, digits, '.', '_', '-' and not start with '.'"
        exit 1 ;;
esac

if [ "$SERVER_HOST" = "yourserver" ]; then
    echo "Error: configuration not set. Copy config.example.sh to"
    echo "~/.config/workflow-setup/config.sh, edit it, and source it (see scripts/README.md)."
    exit 1
fi

REPO_PATH="$CODE_DIR/$REPO_NAME"
REMOTE_PATH="$SERVER_GIT_PATH/$REPO_NAME.git"

if [ -d "$REPO_PATH" ]; then
    echo "Error: $REPO_PATH already exists locally"
    exit 1
fi

echo "→ Creating bare repo on server at $REMOTE_PATH"
ssh "$SERVER_HOST" bash <<EOF
set -e
if [ -d "$REMOTE_PATH" ]; then
    echo "Error: $REMOTE_PATH already exists on server"
    exit 1
fi
mkdir -p "$REMOTE_PATH"
cd "$REMOTE_PATH"
git init --bare -q
EOF

echo "→ Creating local repo at $REPO_PATH"
mkdir -p "$REPO_PATH"
cd "$REPO_PATH"

cat > README.md <<EOF
# $REPO_NAME

Private repository. Canonical remote is a bare repo on the personal server.
Not mirrored to any commercial Git host.

**Remember to ensure this repo is included in your independent backup of the
server's Git storage.**
EOF

cat > .gitignore <<'EOF'
.DS_Store
*.swp
*~
EOF

git init -q -b main
git add .
git commit -q -m "Initial commit"
git remote add origin "$SERVER_HOST:$REMOTE_PATH"
git push -u origin main

echo ""
echo "✓ Private repo created:"
echo "    Local:   $REPO_PATH"
echo "    Remote:  $SERVER_HOST:$REMOTE_PATH"
echo ""
echo "  WARNING: This repo exists ONLY on your server and your local clones."
echo "  Ensure your server backup mechanism includes $SERVER_GIT_PATH"
