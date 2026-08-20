#!/usr/bin/env bash
# new-teaching-repo.sh
#
# Creates a new teaching repository with standard structure, configures
# multi-remote push (GitHub + GitLab + your server), and creates the
# parallel Nextcloud assets folder.
#
# No GitHub/GitLab CLI needed: the script pauses so you can create the GitHub
# repo in the browser (one click), and GitLab creates the project automatically
# on first push (push-to-create).
#
# Assumes:
#   - SSH keys with push access to github.com and gitlab.com
#   - Your server bare repos live under a known SSH path
#   - Nextcloud teaching folder is at ~/20_teaching/
#   - Repos live under ~/code/
#
# Usage: ./new-teaching-repo.sh <repo-name> [--private]

set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────
GITHUB_USER="${GITHUB_USER:-yourgithubuser}"
GITLAB_USER="${GITLAB_USER:-yourgitlabuser}"
SERVER_HOST="${SERVER_HOST:-yourserver}"
SERVER_GIT_PATH="${SERVER_GIT_PATH:-/var/git}"
CODE_DIR="${CODE_DIR:-$HOME/code}"
TEACHING_DIR="${TEACHING_DIR:-$HOME/20_teaching}"
# ───────────────────────────────────────────────────────────────────────────

REPO_NAME="${1:-}"
VISIBILITY="public"

if [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <repo-name> [--private]"
    exit 1
fi

case "${2:-}" in
    "") ;;
    --private) VISIBILITY="private" ;;
    *) echo "Unknown option: $2"; echo "Usage: $0 <repo-name> [--private]"; exit 1 ;;
esac

case "$REPO_NAME" in
    *[!A-Za-z0-9._-]*|.*)
        echo "Error: repo name must contain only letters, digits, '.', '_', '-' and not start with '.'"
        exit 1 ;;
esac

if [ "$GITHUB_USER" = "yourgithubuser" ] || [ "$SERVER_HOST" = "yourserver" ]; then
    echo "Error: configuration not set. Copy config.example.sh to"
    echo "~/.config/workflow-setup/config.sh, edit it, and source it (see scripts/README.md)."
    exit 1
fi

REPO_PATH="$CODE_DIR/$REPO_NAME"
ASSETS_PATH="$TEACHING_DIR/$REPO_NAME"

if [ -d "$REPO_PATH" ]; then
    echo "Error: $REPO_PATH already exists"
    exit 1
fi

echo "→ Creating teaching repo: $REPO_NAME (visibility: $VISIBILITY)"

# ─── Local repo skeleton ───────────────────────────────────────────────────
mkdir -p "$REPO_PATH"/{lectures,slides,problem-sets,images,build}
cd "$REPO_PATH"

cat > README.md <<EOF
# $REPO_NAME

Teaching materials.

## Structure

- \`lectures/\` — LaTeX lecture notes
- \`slides/\` — LaTeX slides
- \`problem-sets/\` — LaTeX problem sets
- \`images/\` — figures embedded in the compiled PDFs
- \`build/\` — compiled PDFs (committed)

Large presentation-time assets (videos, external PDFs) live in:
\`~/20_teaching/$REPO_NAME/\`

## Building

\`\`\`bash
./build.sh
\`\`\`
EOF

cat > .gitignore <<'EOF'
# LaTeX build artifacts (except the final PDFs in build/)
*.aux
*.log
*.synctex.gz
*.fdb_latexmk
*.fls
*.toc
*.out
*.nav
*.snm
*.vrb
*.bbl
*.blg
*.idx
*.ilg
*.ind

# Editor and OS
.DS_Store
*.swp
*~
.vscode/
.idea/
EOF

cat > .gitattributes <<'EOF'
# Mark PDFs as binary so Git doesn't try to diff or merge them
*.pdf binary
*.png binary
*.jpg binary
*.jpeg binary
EOF

cat > build.sh <<'EOF'
#!/usr/bin/env bash
# Build all LaTeX documents into build/
set -e
cd "$(dirname "$0")"

for dir in lectures slides problem-sets; do
    if [ -d "$dir" ]; then
        find "$dir" -name '*.tex' -exec latexmk -pdf -interaction=nonstopmode \
            -outdir="build/$dir" {} \;
    fi
done

echo "✓ Build complete. PDFs in build/"
EOF
chmod +x build.sh

git init -q -b main
git add .
git commit -q -m "Initial repository structure"

# ─── Create bare repo on server ────────────────────────────────────────────
echo "→ Creating bare repo on server"
ssh "$SERVER_HOST" "mkdir -p '$SERVER_GIT_PATH/$REPO_NAME.git' && \
    cd '$SERVER_GIT_PATH/$REPO_NAME.git' && \
    git init --bare -q"

# ─── Configure multi-remote push on origin ─────────────────────────────────
git remote add origin "git@github.com:$GITHUB_USER/$REPO_NAME.git"
git remote set-url --add --push origin "git@github.com:$GITHUB_USER/$REPO_NAME.git"
git remote set-url --add --push origin "git@gitlab.com:$GITLAB_USER/$REPO_NAME.git"
git remote set-url --add --push origin "$SERVER_HOST:$SERVER_GIT_PATH/$REPO_NAME.git"

# ─── Create parallel Nextcloud assets folder ──────────────────────────────
echo "→ Creating Nextcloud assets folder at $ASSETS_PATH"
mkdir -p "$ASSETS_PATH/videos"
cat > "$ASSETS_PATH/README.md" <<EOF
# $REPO_NAME — assets

Large presentation-time assets that don't fit in Git.

Corresponding source repo: \`~/code/$REPO_NAME/\`

- \`videos/\` — video clips shown during class
EOF

# ─── Create the GitHub repo (manual, in the browser) ───────────────────────
# GitHub has no push-to-create, so this is the one manual step.
echo ""
echo "→ Create the GitHub repo now (empty — do NOT add a README or .gitignore):"
echo ""
echo "    https://github.com/new?name=$REPO_NAME&visibility=$VISIBILITY"
echo ""
echo "  Owner: $GITHUB_USER   Name: $REPO_NAME   Visibility: $VISIBILITY"
read -r -p "  Press Enter when the GitHub repo exists... "

# GitLab needs no pre-creation: pushing over SSH creates the project
# (push-to-create), always as PRIVATE.
echo "→ Pushing to all remotes (GitLab project is created by this push)"
git push -u origin main || {
    echo ""
    echo "Error: push failed. Everything local is in place — fix the remote"
    echo "(does the GitHub repo exist?) and retry with:"
    echo "    cd $REPO_PATH && git push -u origin main"
    exit 1
}

if [ "$VISIBILITY" = "public" ]; then
    echo ""
    echo "  NOTE: GitLab push-to-create makes the project PRIVATE. Set it to"
    echo "  public at: https://gitlab.com/$GITLAB_USER/$REPO_NAME/edit"
fi

echo ""
echo "✓ Repository created:"
echo "    Source:  $REPO_PATH"
echo "    Assets:  $ASSETS_PATH"
echo "    Remotes:"
git remote -v | grep push | sed 's/^/      /'
