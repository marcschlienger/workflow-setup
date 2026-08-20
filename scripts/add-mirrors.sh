#!/usr/bin/env bash
# add-mirrors.sh
#
# Reconfigures an existing repo's origin remote to push to multiple destinations.
# Handles the "first --add --push replaces the implicit URL" quirk correctly.
#
# Run from inside the repo. Assumes origin currently points at your primary
# canonical remote (typically GitHub or GitLab).
#
# Usage:
#   ./add-mirrors.sh                          # add GitLab + server as extra push targets
#   ./add-mirrors.sh --github --gitlab        # explicit destinations
#   ./add-mirrors.sh --github --server        # skip GitLab
#
# Configuration via environment variables (see below).

set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────
GITHUB_USER="${GITHUB_USER:-yourgithubuser}"
GITLAB_USER="${GITLAB_USER:-yourgitlabuser}"
SERVER_HOST="${SERVER_HOST:-yourserver}"
SERVER_GIT_PATH="${SERVER_GIT_PATH:-/var/git}"
# ───────────────────────────────────────────────────────────────────────────

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: not inside a Git repository"
    exit 1
fi

REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")

# Default: enable all three destinations
ADD_GITHUB=true
ADD_GITLAB=true
ADD_SERVER=true

# If any explicit flags are given, only add the specified ones
if [ $# -gt 0 ]; then
    ADD_GITHUB=false
    ADD_GITLAB=false
    ADD_SERVER=false
    for arg in "$@"; do
        case "$arg" in
            --github) ADD_GITHUB=true ;;
            --gitlab) ADD_GITLAB=true ;;
            --server) ADD_SERVER=true ;;
            *) echo "Unknown option: $arg"; exit 1 ;;
        esac
    done
fi

if { [ "$ADD_GITHUB" = true ] && [ "$GITHUB_USER" = "yourgithubuser" ]; } || \
   { [ "$ADD_GITLAB" = true ] && [ "$GITLAB_USER" = "yourgitlabuser" ]; } || \
   { [ "$ADD_SERVER" = true ] && [ "$SERVER_HOST" = "yourserver" ]; }; then
    echo "Error: configuration not set. Copy config.example.sh to"
    echo "~/.config/workflow-setup/config.sh, edit it, and source it (see scripts/README.md)."
    exit 1
fi

echo "→ Repository: $REPO_NAME"
echo "→ Current remotes:"
git remote -v | sed 's/^/    /'
echo ""

# Determine current fetch URL for origin (will remain the fetch URL)
CURRENT_FETCH=$(git remote get-url origin 2>/dev/null || echo "")
if [ -z "$CURRENT_FETCH" ]; then
    echo "Error: no origin remote configured. Add one first."
    exit 1
fi

# Clear existing push URLs so we can set them cleanly
# (git remote set-url --delete --push accepts a regex matching URLs to remove)
git remote set-url --delete --push origin '.*' 2>/dev/null || true

# Re-add push URLs. IMPORTANT: the first --add --push replaces the implicit
# push URL (the fetch URL), so we must explicitly add every destination we want.
FIRST_PUSH_ADDED=false

add_push() {
    local url="$1"
    local label="$2"
    git remote set-url --add --push origin "$url"
    echo "  + $label: $url"
    FIRST_PUSH_ADDED=true
}

echo "→ Configuring push URLs on origin:"
if [ "$ADD_GITHUB" = true ]; then
    add_push "git@github.com:$GITHUB_USER/$REPO_NAME.git" "GitHub"
fi
if [ "$ADD_GITLAB" = true ]; then
    add_push "git@gitlab.com:$GITLAB_USER/$REPO_NAME.git" "GitLab"
fi
if [ "$ADD_SERVER" = true ]; then
    add_push "$SERVER_HOST:$SERVER_GIT_PATH/$REPO_NAME.git" "Server backup"
fi

if [ "$FIRST_PUSH_ADDED" = false ]; then
    echo "Error: no destinations selected"
    exit 1
fi

echo ""
echo "✓ New remote configuration:"
git remote -v | sed 's/^/    /'
echo ""
echo "  Fetch will use: $CURRENT_FETCH"
echo "  git push will now send to all configured push URLs."

if [ "$ADD_GITHUB" = true ]; then
    echo ""
    echo "  NOTE: GitHub cannot create repos on push. If it doesn't exist yet,"
    echo "  create it (empty) at: https://github.com/new?name=$REPO_NAME"
fi
if [ "$ADD_GITLAB" = true ]; then
    echo "  NOTE: GitLab creates the project on first push (as PRIVATE)."
fi
