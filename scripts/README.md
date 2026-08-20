# Workflow Setup Scripts

Convenience scripts implementing the architecture from
`architecture-overview.md`. Each script is standalone and idempotent
where reasonable.

## Setup

1. **Copy the config template:**

   ```bash
   mkdir -p ~/.config/workflow-setup
   cp config.example.sh ~/.config/workflow-setup/config.sh
   $EDITOR ~/.config/workflow-setup/config.sh
   ```

2. **Source it from your shell rc file (`~/.zshrc`, `~/.bashrc`):**

   ```bash
   [ -f ~/.config/workflow-setup/config.sh ] && \
       source ~/.config/workflow-setup/config.sh
   ```

3. **Make scripts executable and add to `$PATH` (optional):**

   ```bash
   chmod +x *.sh
   # Optionally symlink into ~/bin or add this directory to PATH
   ```

## Prerequisites

No GitHub or GitLab CLI is needed — only Git and SSH:

- **SSH keys with push access to github.com and gitlab.com** — GitHub repos
  are created manually in the browser (the scripts pause and give you the
  link); GitLab projects are created automatically on first push
  (push-to-create, always as private)
- **SSH access to your server** — configured in `~/.ssh/config` so
  `ssh $SERVER_HOST` works without further arguments
- **Git** — with your identity configured (`git config --global user.name/email`)

## Scripts

### `setup-nextcloud-folders.sh`

One-time setup that creates the sibling folder structure at `$HOME`
(00_inbox through 90_archive) and prints instructions for configuring
Nextcloud sync connections. Nextcloud connections must be set up
manually via the desktop client — this script prepares the local
targets and tells you what to pair with what.

```bash
./setup-nextcloud-folders.sh
```

Run once per machine.

### `new-teaching-repo.sh`

Creates a new teaching repository end-to-end:

- Local repo in `$CODE_DIR/<name>` with standard structure (`lectures/`,
  `slides/`, `problem-sets/`, `images/`, `build/`, `.gitignore`,
  `.gitattributes`, `build.sh`, `README.md`)
- Bare repo on your server for backup
- Multi-remote push configured on `origin` (pushes to all three)
- GitHub repo: the script pauses and gives you a prefilled
  `github.com/new` link (public by default, or `--private`) — create it
  empty, press Enter, and the script continues
- GitLab project: created automatically by the first push
  (push-to-create). GitLab always creates it private; for public repos
  the script prints the settings link to flip visibility
- Parallel Nextcloud assets folder at `$TEACHING_DIR/<name>`
- Initial commit pushed to all remotes

```bash
./new-teaching-repo.sh analysis-2026
./new-teaching-repo.sh advanced-topics --private
```

### `new-private-repo.sh`

Creates a repository whose only remote is your private server bare repo.
Nothing on commercial hosts. For sensitive material.

```bash
./new-private-repo.sh personal-journal
```

**Reminder:** ensure your server backup mechanism includes
`$SERVER_GIT_PATH` — with no commercial host mirror, the server (and
your local clones) are the only copies.

### `create-server-bare-repo.sh`

Just creates a bare repo on the server, without any local repo
scaffolding. Useful for adding server backup to an existing repo that
was created without it, or for setting up a private repo before you're
ready to clone locally.

```bash
./create-server-bare-repo.sh some-repo-name
```

### `add-mirrors.sh`

Reconfigures an existing repo's `origin` to push to multiple destinations.
Run from inside the repo. By default adds all three (GitHub + GitLab +
server); pass flags to be selective.

```bash
cd ~/code/existing-project
/path/to/workflow-setup/scripts/add-mirrors.sh   # add all three destinations
add-mirrors.sh --github --gitlab     # skip server (if scripts are on $PATH)
add-mirrors.sh --server              # server only (removes GitHub push)
```

The GitHub repo must already exist (GitHub has no push-to-create);
GitLab creates the project on the first push, as private.

Handles the "first `--add --push` replaces the implicit URL" Git quirk
correctly by clearing existing push URLs and re-adding all destinations
explicitly.

### Agent VMs (in home-server-provisioning)

Agent sandboxes are **not** scripted here. They are provisioned on the
server by the
[home-server-provisioning](https://github.com/marcschlienger/home-server-provisioning)
repo: `scripts/new-agent-vm.sh <task> --git <repo>` creates a persistent
Incus VM with the repo bind-mounted from `GIT_REPOS_ROOT` — no clone and
no agent credentials. See that repo's `SETUP.md` for the full workflow.

## Directory Assumptions

The scripts assume the following home layout (configurable via
environment variables):

```
~/code/             ← Git working trees
~/20_teaching/      ← Nextcloud-synced teaching assets
```

Change `CODE_DIR` and `TEACHING_DIR` in the config if your layout differs.

## Extending

These scripts intentionally cover the common workflows without becoming
elaborate. If you find yourself doing something repetitive that isn't
scripted here, adding another small script alongside them is the
right move — better than making any single one of them fancier.

Suggested additions if your workflow needs them:

- `archive-repo.sh` — move a repo from `$CODE_DIR` to an archive
  location and mark it read-only
- `verify-mirrors.sh` — check that all configured remotes have the same
  refs (useful periodic sanity check)
- `new-domain-folder.sh` — create a new domain folder at the home level
  with Nextcloud sync connection prep

## License

MIT — see [`LICENSE`](../LICENSE) at the repository root.
