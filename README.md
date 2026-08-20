# Workflow Setup

Cross-platform sync and version-control workflow for macOS, iOS, iPadOS, and
Linux: Nextcloud for files, Git for versioned work, an Incus server for AI
agent sandboxes, Working Copy for iPad access.

## Start here

- **[`architecture-overview.md`](./architecture-overview.md)** — the design:
  guiding principles, directory layout, propagation model, teaching-materials
  structure, Git remotes, agent workflow, migration sequence.
- **[`scripts/`](./scripts/)** — convenience scripts implementing the
  architecture (folder setup, repo scaffolding, multi-remote mirrors). Setup
  and per-script docs in [`scripts/README.md`](./scripts/README.md).

## Design in one paragraph

Two propagation systems, each doing what it's best at: Nextcloud syncs
documents, media, and teaching assets across PARA-style sibling folders in
`$HOME`; Git versions code and LaTeX in `~/15-Code/`, pushing to GitHub +
GitLab + a self-hosted bare repo in one `git push` (sensitive repos go to the
server only). AI agents run in persistent Incus VMs with repos bind-mounted
from the server — no agent credentials — provisioned by the separate
[home-server-provisioning](https://github.com/marcschlienger/home-server-provisioning)
repo.

## Requirements

Git and SSH only — no GitHub/GitLab CLIs. See
[`scripts/README.md`](./scripts/README.md) for setup.

## License

MIT — see [`LICENSE`](./LICENSE).
