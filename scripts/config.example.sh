#!/usr/bin/env bash
# config.example.sh
#
# Copy this file to ~/.config/workflow-setup/config.sh and edit the values.
# Source it from your shell rc file to make these variables available to
# all workflow-setup scripts:
#
#   [ -f ~/.config/workflow-setup/config.sh ] && \
#       source ~/.config/workflow-setup/config.sh
#
# Then the scripts will pick up the values without you needing to pass them
# every time.

# ─── Git hosts ─────────────────────────────────────────────────────────────
export GITHUB_USER="yourgithubuser"
export GITLAB_USER="yourgitlabuser"

# ─── Your Incus server (used for backups and private repos) ───────────────
# Should be an SSH-reachable host. Configure ~/.ssh/config for the alias
# to avoid needing full user@host syntax here.
export SERVER_HOST="yourserver"
# Bare repos (backup / canonical-private). Distinct from GIT_REPOS_ROOT
# (default /data/git) in home-server-provisioning, which holds the WORKING
# repos that agent VMs bind-mount.
export SERVER_GIT_PATH="/var/git"

# ─── Local directory conventions ──────────────────────────────────────────
export CODE_DIR="$HOME/15_code"
export TEACHING_DIR="$HOME/20_teaching"
