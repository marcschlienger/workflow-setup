# Cross-Platform Sync & Version Control Architecture

Final design for a multi-device workflow across **macOS, iOS, iPadOS, and Linux**,
with self-hosted Nextcloud, Git-based collaboration, AI agents running on an
Incus server, and iPad access via Working Copy.

---

## Guiding Principles

The architecture that emerged from this discussion follows a few principles that
were arrived at gradually:

1. **Propagation and organization are separate concerns.** How bits reach machines
   is not the same as how work is categorized. Trying to unify them creates friction.
2. **Choose the tool by workflow, not by file format.** LaTeX is plain text, but
   that alone doesn't dictate Git. What dictates Git is the agent-review workflow,
   which needs branching and diffs.
3. **Add infrastructure only when it solves a real, observed problem.** Preemptive
   infrastructure (mirrors, sync bridges, complex automation) tends to become
   maintenance burden without matching value.
4. **Simpler is better.** Every iteration in this discussion made the architecture
   smaller, not larger. That is a good sign.

---

## Directory Layout

Top-level folders in `$HOME`, each with a single clear purpose and propagation
mechanism. The Johnny.Decimal-style numeric prefixes provide visual grouping
without requiring a shared parent directory.

```
~/00-Inbox/           ← Nextcloud sync — uncategorized incoming
~/10-Projects/        ← Nextcloud sync — non-code current work
~/15-Code/            ← Git — versioned source, repos live here directly
~/20-Teaching/        ← Nextcloud sync — teaching assets (videos, large media)
~/30-Research/        ← Nextcloud sync — research domain
~/40-Admin/           ← Nextcloud sync — admin domain
~/60-Media/           ← media library (music, ebooks — managed by apps)
~/70-Vault/           ← Cryptomator vault via Nextcloud (see notes)
~/80-Reference/       ← Nextcloud sync — small, searchable working reference
~/90-Archive/         ← Nextcloud sync — done work
```

Each folder is a separate Nextcloud sync connection, giving flexibility to sync
different subsets on different machines (e.g. Linux may skip `~/60-Media/`; iPad
may only see the Teaching materials it needs).

The relaxed PARA model keeps **Inbox, Projects, Archive** from the original,
replaces **Areas** with explicit **domain folders** (Teaching, Research, Admin),
and replaces **Resources** with a smaller, flat **Reference** folder plus
dedicated Media handling.

---

## Propagation Model

Two independent propagation systems, each doing what it's best at:

| Content type | Propagation | Notes |
|---|---|---|
| LaTeX source, code, small figures | Git | Versioned; agents can work on it safely |
| Compiled PDFs | Git (in the same repo) | Committed as deliverables, no build/copy step |
| Videos, large media, static assets | Nextcloud | Too big or wrong shape for Git |
| Documents, notes, admin files | Nextcloud | Native fit; server-side file versioning |
| KeePass database | Nextcloud (WebDAV) | Existing setup |
| Calendars & contacts | Nextcloud (CalDAV/CardDAV) | Existing setup |
| Encrypted vaults | Cryptomator over Nextcloud | Individual-file encryption, sync-friendly |

**Rule for routing new content:**

1. Source code or version-controlled work → `~/15-Code/`
2. Uncategorized → `~/00-Inbox/`
3. Active work with a deadline → `~/10-Projects/`
4. Belongs to a specific domain → the domain folder
5. Consumption media → `~/60-Media/` (managed by media apps)
6. Small searchable reference → `~/80-Reference/`
7. Done → `~/90-Archive/`

**Rule for build-time vs presentation-time assets:**

- Embedded in the PDF (small images, diagrams) → in the Git repo
- Shown live during class (videos, large clips) → in Nextcloud

---

## Teaching Materials: The Two-Half Model

Each teaching subject has parallel structures with the **same name** in both trees:

```
~/15-Code/analysis-2026/          ← Git: LaTeX source + compiled PDFs + small figures
~/20-Teaching/analysis-2026/      ← Nextcloud: large media only (< 10 files typically)
```

**Everything for a lesson except the largest assets lives in the Git repo:**

```
~/15-Code/analysis-2026/
  lectures/          ← LaTeX source
  slides/            ← LaTeX source
  problem-sets/      ← LaTeX source
  images/            ← small figures used in builds
  build/             ← compiled PDFs, committed
  build.sh           ← build script
  .gitattributes     ← marks PDFs as binary
  .gitignore
  README.md
```

**Compiled PDFs are committed to the repo.** For teaching materials the PDF is
a deliverable, not an intermediate build artifact. Committing it eliminates the
build-and-copy friction, makes iPad access trivial (via Working Copy), and
captures what was actually presented.

The tradeoff (slight repo bloat, no diffs on binaries) is small at teaching-material
scale — typically 100–300 MB per course-year, which Git handles comfortably.

The Nextcloud side holds only the handful of large presentation-time assets
(videos, external PDFs) that Git can't handle well and that are opened directly
during class rather than embedded in the compiled document.

---

## Git Remotes

Every repo (or at least every repo that matters) pushes to multiple destinations
via the **push-URL approach** — one remote, multiple push URLs. This means
`git push` is atomic across all destinations without needing aliases or scripts.

### Non-sensitive repos

Three destinations for redundancy and self-controlled backup:

```
origin fetch:  git@github.com:you/repo.git
origin push:   git@github.com:you/repo.git
origin push:   git@gitlab.com:you/repo.git
origin push:   git@yourserver:git/repo.git
```

- **GitHub / GitLab** — canonical, collaboration surface, mature tooling.
  Redundant across two commercial hosts to protect against account/policy issues.
- **Your Incus server bare repo** — backup under your own control. Passive
  receiver; no hooks, no cron jobs, no sync logic.

### Sensitive repos

Server bare repo as the **only** remote. Nothing on commercial hosts. Requires a
second self-controlled backup location (a home NAS, encrypted external drive,
second server) since there's no commercial host acting as implicit redundancy.

---

## Agent Workflow

AI agents run in **persistent Incus VMs** on the server, provisioned by the
[home-server-provisioning](https://github.com/marcschlienger/home-server-provisioning)
repo (`scripts/new-agent-vm.sh`). They work on Git repos to enable safe
review-and-integrate cycles.

**Why Git for agent work:**

- Isolation via branches — agent output doesn't touch your real work until you accept it
- Diffing — you can see exactly what changed
- Rollback is free — reject the branch, no cleanup needed
- Attribution — agent commits are distinguishable from human commits

**Agent workflow:**

1. Repos the agent should work on live on the server host under
   `GIT_REPOS_ROOT` (default `/data/git`)
2. `new-agent-vm.sh <task> --git <repo>` creates VM `agent-<task>` with the
   repo **bind-mounted** at `/home/admin/project` — no clone, no agent SSH keys
3. Agent works on a branch: `agent/<task>` (never `main`)
4. You review **on the host**: `git diff main..agent/<task>`; merge if good,
   delete the branch if not; push upstream yourself from the host
5. Re-running `new-agent-vm.sh <task>` re-enters the same VM with all state
   intact (partial work, agent auth, shell history); `incus stop` pauses it,
   `incus delete` when the task is truly done

**The agent cannot reach your remotes.** The VM has no private keys and is not
on the tailnet — the agent sees only the bind-mounted project. All pushes to
GitHub/GitLab/server happen from repos you control, as you. This supersedes an
earlier ephemeral-container design where agents cloned from and pushed to
GitHub directly with a scoped deploy key — the bind-mount model needs no agent
credentials at all and keeps working state across sessions.

**Branch protection on `main`** on GitHub/GitLab remains a good belt-and-braces
guard for your own mistakes, but is no longer what stands between the agent and
your canonical branch — the missing credentials are.

---

## iPad Workflow

**Working Copy** is the primary Git client on iPad. It integrates with the
Files app properly (unlike Nextcloud's flakier File Provider integration).

- Clone teaching repos in Working Copy
- Pull before class to get latest PDFs and source
- View compiled PDFs directly in Working Copy or via Files app
- For lessons referencing a video: also open the corresponding Nextcloud folder
  in the Nextcloud app (rare, not per-lesson)

**No iCloud pipeline is needed.** Earlier iterations of this design used iCloud
as an iPad delivery surface for PDFs, requiring a Mac-as-bridge. That entire
subsystem became unnecessary once Working Copy took the primary iPad role and
PDFs got committed to the repo.

Nextcloud iOS app is still used for accessing large media (videos) and other
Nextcloud-hosted content — just not for the teaching source or PDFs.

---

## Handling Special Content

### VeraCrypt containers → Cryptomator

Half-gigabyte VeraCrypt containers sync badly (whole file re-uploads on any
change; concurrent mount can corrupt). Migrate to **Cryptomator**, which encrypts
files individually and works file-by-file with sync tools. Native apps on all
four platforms. Vault lives at `~/70-Vault/` synced via Nextcloud.

Keep VeraCrypt only if you specifically need hidden volumes or plausible
deniability — otherwise Cryptomator is strictly better for this workflow.

### Music and ebooks

Live in `~/60-Media/`, managed by their respective apps (Music.app, Calibre,
Apple Books, etc.). Not synced via Nextcloud unless the collection is small.
For larger libraries, use a media server (Jellyfin, Navidrome) or streaming.

Never mix consumption media with working reference. `~/80-Reference/` stays
small and searchable; `~/60-Media/` holds the large consumption libraries with
their own tooling.

### Teaching videos

Fewer than ten static, largish files supporting occasional lessons. Fit
comfortably in `~/20-Teaching/<subject>/videos/`, synced via Nextcloud.
Nextcloud's on-demand download on iPad means they take no local storage until
tapped. No dedicated media server needed at this scale.

---

## What Was Deliberately Left Out

Ideas considered and rejected during the discussion, with reasons:

- **Nextcloud + iCloud hybrid for PARA** — split organization across two clouds
  forces routing decisions by storage location, breaks PARA's clean categorization.
- **Resilio Sync** — proprietary, weaker privacy story, only solves one problem.
- **iCloud with ADP as full replacement** — no Linux client, no WebDAV, loses
  Nextcloud's server-side utilities.
- **Codeberg as canonical Git host** — user migrated away due to platform changes;
  GitHub + GitLab redundancy replaces it.
- **`.repo` folder suffix + Nextcloud exclusion patterns** — solved the wrong
  problem; keeping repos out of PARA entirely is cleaner.
- **Manifest file bridging PARA and `~/code/`** — became unnecessary once repos
  moved to `~/15-Code/` as a sibling folder rather than being hidden inside PARA.
- **iCloud PDF delivery pipeline (Mac-as-bridge)** — obviated by Working Copy on
  iPad and by committing PDFs to the repo.
- **Server bare repo as agent mirror** — solved problems (speed, rate limits,
  offline) that weren't real at this scale. Kept as backup instead.
- **Contributors accessing server bare repo** — collaboration lives on GitHub/GitLab
  where the tooling belongs; server stays private infrastructure.

---

## The Full Picture

```
                    GitHub  ⇄  GitLab            (redundant canonical hosts)
                       ↑ ↓         ↑ ↓
                       └────┬──────┘
                            │  push (via multi-URL origin)
                            │  clone/pull
                            │
Workstation  ──────────────┤
  ~/15-Code/*  ────────────┤
  ~/20-Teaching/*  ────────┼──── Nextcloud server ──── iPad
                            │                              │
                            │                              └── Working Copy (Git)
                            │                              └── Nextcloud app (assets)
                            │                              └── Files app (both)
                            │
Incus server ──────────────┤
  Agent VMs (persistent)   │
    ├─ agent-analysis ─────┤  ← repo bind-mounted from
    ├─ agent-research ─────┤    GIT_REPOS_ROOT (/data/git)
    └─ ...                 │
                            │
                    Bare repos on server
                    (backup for public repos,
                     canonical for sensitive repos)
```

---

## Migration & Adoption Sequence

Not everything needs to happen at once. A reasonable order:

1. **Reorganize Nextcloud into individual folder syncs** (each PARA folder as
   its own connection). This alone unlocks many of the flexibility gains.
2. **Move Git repos to `~/15-Code/`** as a sibling to PARA folders. Natural
   names, no exclusion patterns.
3. **Set up multi-remote push** on existing repos (GitHub + GitLab + server).
4. **Commit compiled PDFs** to teaching repos. Add `build.sh` and `.gitattributes`.
5. **Set up Working Copy on iPad** with the teaching repos. Retire the iCloud
   pipeline if one exists.
6. **Provision the Incus server** with the home-server-provisioning repo
   (images, agent VMs, `GIT_REPOS_ROOT`). Start with one course and one agent task.
7. **Migrate VeraCrypt to Cryptomator** for encrypted storage.
8. **Live with it for a semester.** Adjust based on what actually causes friction.

---

## Conclusions

1. **The two propagation systems (Git and Nextcloud) don't compose cleanly, and
   trying to force them into a single tree creates friction.** The right answer
   is parallel sibling trees under matching names — the split follows the nature
   of the content, not a workaround.

2. **Git for teaching source is justified specifically by the agent workflow.**
   For pure human editing, Nextcloud's file versioning would be enough. Agents
   need branches and reviewable diffs, which only Git provides.

3. **Commit compiled PDFs to the repo.** The traditional "don't commit build
   outputs" rule doesn't apply because PDFs are the deliverable, sizes are
   modest, and it eliminates the build-and-copy friction.

4. **The server holds Git repos in two distinct roles, and agents get neither
   as a remote.** Bare repos (`SERVER_GIT_PATH`, e.g. `/var/git`) are passive
   backup for public repos and canonical storage for private ones. Working
   repos (`GIT_REPOS_ROOT`, e.g. `/data/git`) are what agent VMs see, via
   bind-mount. Agents hold no credentials and never talk to GitHub/GitLab.

5. **Multi-remote push via push-URL configuration is Git-native and works with
   all tools.** Superior to shell aliases; a single `git push` reaches all
   destinations atomically.

6. **Working Copy on iPad replaces the entire iCloud delivery pipeline.** With
   PDFs committed to the repo, iPad access is just `git pull` — no bridge, no
   scripts, no launchd jobs.

7. **The Johnny-Decimal-style flat sibling layout scales better than nested
   PARA.** Each top-level folder is typed by what it holds and propagates the
   way its content wants to propagate. PARA categories (Inbox, Projects, Archive)
   sit alongside domain folders and specialized folders (Code, Media) rather
   than containing them.

8. **Infrastructure should solve real problems.** Every iteration of this design
   removed something that wasn't earning its keep. The final architecture is
   smaller than the intermediate ones and does more useful work.
