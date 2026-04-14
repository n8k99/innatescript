# Vault-Repo Sync Daemon — Design Spec

## Problem

Four InnateScript documentation files exist in both the Obsidian vault (`~/Documents/Droplet-Org/The Work/Innatescript/`) and the git repo (`~/Development/innatescript/`). The vault is the source of truth, but repo-side edits happen too. Syncing is currently manual — easy to forget, leading to drift.

This pattern will recur across vault projects. The solution must be modular and config-driven, not single-use.

## Design

### Architecture

Three layers:

1. **Config layer** — A YAML file defining sync pairs per project. Each entry maps a vault path to a repo path. Adding a new project is adding a YAML block.

2. **Sync engine** — Core logic: detects changes via `watchdog` inotify events, compares against last-known state, decides sync/conflict/skip, performs the copy, writes changelog entries. Knows nothing about specific projects.

3. **Daemon runner** — Loads config, spins up watchers for all defined pairs, handles signals (SIGHUP to reload config), runs as a systemd user service.

```
vault-sync.yaml          # config: file pair mappings per project
  |
  v
daemon (runner)           # loads config, manages watchers
  |
  v
sync engine               # state tracking, conflict detection, copy, changelog
  |
  +-- watchdog watchers   # inotify on both sides
  +-- changelog writer    # appends to vault CHANGELOG.md per project
```

### Config Format

```yaml
projects:
  innatescript:
    vault_base: ~/Documents/Droplet-Org/The Work/Innatescript
    changelog: CHANGELOG.md  # relative to vault_base
    pairs:
      - vault: InnateScript.md
        repo: ~/Development/innatescript/docs/specs/InnateScript.md
      - vault: README.md
        repo: ~/Development/innatescript/README.md
      - vault: ROADMAP.md
        repo: ~/Development/innatescript/docs/ROADMAP.md
      - vault: REQUIREMENTS.md
        repo: ~/Development/innatescript/docs/REQUIREMENTS.md
```

### Sync Logic

**State file:** `~/.local/state/vault-sync/state.json` — records last-known mtime for each side of each pair. On first run (no state file), snapshots current mtimes as baseline (assumes files are in sync).

**Event flow:**

1. `watchdog` fires a file-modified event on either side
2. Engine debounces (500ms wait for editor write-rename dances)
3. Engine reads current mtime of both sides of that pair
4. Compares both mtimes against last-known state:

| Vault changed? | Repo changed? | Action |
|---|---|---|
| Yes | No | Copy vault -> repo, update state, log one-liner to CHANGELOG |
| No | Yes | Copy repo -> vault, update state, log one-liner to CHANGELOG |
| Yes | Yes | **Conflict** — don't touch either file, log conflict to CHANGELOG |
| No | No | Spurious event, skip |

5. After any action, write updated mtimes to state file

**Error handling:** If a copy fails (permissions, disk full), log the error to CHANGELOG and leave both files untouched — same as conflict behavior.

### CHANGELOG Format

Lives at `~/Documents/Droplet-Org/The Work/Innatescript/CHANGELOG.md` (vault, project folder). Created automatically with proper frontmatter if it doesn't exist.

```markdown
---
title: InnateScript Sync Changelog
type: "[[Template]]"
domain: "[[The Work]]"
project: "[[InnateScript]]"
icon: "📜"
Lifestage: "🌱 Seed"
---

# InnateScript Sync Changelog

## Entries

- 2026-04-14 15:32:01 — synced ROADMAP.md (vault -> repo)
- 2026-04-14 15:45:12 — synced README.md (repo -> vault)
- 2026-04-14 16:00:03 — **CONFLICT** README.md — both sides changed since last sync. Neither file modified. Resolve manually.
```

Successful syncs: one-liner. Conflicts: bold **CONFLICT** tag. Errors: bold **ERROR** tag.

### File Layout

```
~/Development/python/vault-sync/
+-- vault_sync/
|   +-- __init__.py
|   +-- config.py        # YAML config loader, path expansion
|   +-- engine.py        # sync logic, conflict detection, state management
|   +-- changelog.py     # vault CHANGELOG writer (creates file w/ frontmatter if missing)
|   +-- watcher.py       # watchdog setup, debounce, event routing to engine
|   +-- daemon.py        # entry point, signal handling (SIGHUP reload), logging
+-- config/
|   +-- vault-sync.yaml  # default config (innatescript pairs)
+-- requirements.txt     # watchdog, pyyaml
+-- README.md
```

### Systemd Service

`~/.config/systemd/user/vault-sync.service`:

```ini
[Unit]
Description=Vault-Repo File Sync Daemon
After=default.target

[Service]
ExecStart=/usr/bin/python3 -m vault_sync.daemon --config %h/Development/python/vault-sync/config/vault-sync.yaml
WorkingDirectory=%h/Development/python/vault-sync
Restart=always
RestartSec=5
Environment=PYTHONPATH=%h/Development/python/vault-sync

[Install]
WantedBy=default.target
```

Enable: `systemctl --user enable --now vault-sync.service`

SIGHUP reloads config without restart.

Logging: stdout to journald (`journalctl --user -u vault-sync`). CHANGELOG is the vault-facing record; journald is the debug-facing record.

### Dependencies

- `watchdog` (inotify filesystem events)
- `pyyaml` (config parsing)
- Python 3 (system)

### Future Extension

Adding a new project = adding a YAML block to `vault-sync.yaml` and sending SIGHUP. No code changes needed.
