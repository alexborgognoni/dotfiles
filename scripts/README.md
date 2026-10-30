# Scripts

Helpers around `../install` for an Ubuntu machine. Everything else (the system
itself) is Nix: see the [root README](../README.md).

| Script | Run by | What it does |
|---|---|---|
| `bootstrap-nix.sh` | `install` | Installs Nix with the official installer, set up for a corporate TLS proxy (root CA, daemon drop-in). Idempotent. |
| `snapshot-system.sh` | `install`, once | One archive in `~/Backups`, encrypted to the sops admin key: `~/.config`, shell dotfiles, `/etc`, lists of everything installed. The undo for the cleanup. |
| `cleanup-ubuntu.sh` | you, optionally, after the install works | Removes what Nix now provides (apt packages installed by hand, snaps, Flatpaks, pip/npm/cargo tools, hand installs) so the machine is "fresh Ubuntu + Nix". Dry run by default. |
| `lib/common.sh` | all of them | `log`, `die`, the repository root, the list loading and the apt origin check. |

## The cleanup, and how to make it safe on another machine

```sh
scripts/cleanup-ubuntu.sh             # dry run: lists everything, changes nothing
scripts/cleanup-ubuntu.sh --apply     # removes it (needs the snapshot; asks once)
```

What it removes is decided in this order for apt packages:

1. **drop list** (`cleanup.d/drop-packages.list`): removed, even from a vendor repository
2. **protect list** (`cleanup.d/protect-packages.list`): kept
3. **installed from outside Ubuntu's archive** (a vendor repository or a local `.deb`): kept. That is how corporate agents look, so unknown ones are safe by default. The dry run lists them.
4. **in the original installation** (`/var/log/installer/initial-status.gz`) or **declared** in `../ansible/ubuntu.yml`: kept
5. everything else that was installed by hand: removed, together with dependencies nothing else needs

The data lives in `cleanup.d/*.list`: one entry per line, `#` comments, `*`
is a wildcard.

| List | Entries |
|---|---|
| `protect-packages.list` | package names never removed (kernels, drivers, firmware, corporate agents) |
| `drop-packages.list` | tool families removed completely (databases, VirtualBox, CUDA) |
| `keep-snaps.list` | snaps that stay (the rest goes) |
| `home-leftovers.list` | old tools and leftovers under `$HOME` |
| `system-leftovers.list` | hand installs outside apt (`/usr/local`, `/opt`) |

**To adapt it** (a coworker's machine): put their company's agents into
`protect-packages.list` and run the dry run. To keep that out of the
repository, create the same file name under
`~/.config/dotfiles/cleanup.d/`; its entries are added to the shipped ones.

Assumptions: Ubuntu with apt and systemd, `/var/log/installer/initial-status.gz`
present (the script stops if it is not), a snapshot in `~/Backups` before
`--apply`. Always read the dry run first.

## Tests

```sh
tests/scripts/run.sh            # all
tests/scripts/run.sh apt-plan   # files matching a pattern
```

Hermetic (a stubbed `apt-cache`, temporary lists), except
`test-cleanup-smoke.sh`, which runs the real dry run (read-only) and skips
itself where it cannot. They cover the list parsing, the apt decision and the
vendor-origin check, the shipped lists (nothing dangerous, no clash with
`ansible/ubuntu.yml`), the repository (Markdown links, no references to
removed files), secrets hygiene (`test-secrets.sh`: sops files encrypted, the right
recipients, no keys in git) and the formatters and linters (`test-lint.sh`, needs
Nix). Run them after editing a list.
