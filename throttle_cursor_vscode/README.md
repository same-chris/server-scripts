
## Cursor Throttle & Ignore

Tools to keep editors (Cursor/VSCode) from hammering your disks.

- **`cursor-throttle.sh`**: wraps Cursor’s own helper binaries (node, rg) so they always run with idle I/O and low CPU priority.
- **`cursorignore-template`**: a ready-made `.cursorignore` blacklist to skip indexing/searching large binary formats in dataset trees.

These are host-side guardrails: they don’t break normal use, but they prevent background indexers from saturating HDD/NVMe and ruining interactivity.

## 1) `cursor-throttle.sh`

Put the script in place:

```bash
sudo install -m 0755 throttle_cursor_vscode/cursor-throttle.sh /usr/local/sbin/cursor-throttle.sh
```

Wrap all users’ Cursor binaries:

```bash
sudo /usr/local/sbin/cursor-throttle.sh apply
```

See which binaries are wrapped, and current Cursor processes:

```bash
sudo /usr/local/sbin/cursor-throttle.sh status
```

Pick a PID from the list and confirm priorities:

```bash
ionice -p <PID>                # should show "Idle"
ps -o pid,ni,cmd -p <PID>      # NI should be 19
```

Restore (removes wrappers and renames `*.real` back to original names):

```bash
sudo /usr/local/sbin/cursor-throttle.sh restore
```

Keep it enforced after updates (optional)

Cursor updates may drop new binaries. Use a simple timer:

- **Service + timer files**: `/etc/systemd/system/cursor-throttle.service`, `/etc/systemd/system/cursor-throttle.timer`
- **Enable**:

```bash
sudo systemctl enable --now cursor-throttle.timer
```

Why this is safe

- **Scope-limited**: only wraps files under `~/.cursor-server/` (per-user Cursor install).
- **Easy to audit**: check for `node.real` / `rg.real`.
- **One-command restore**: `restore`.

## 2) `cursorignore-template`

Use this as `.cursorignore` at dataset mount roots (e.g., `/mnt/HDD18T2/.cursorignore`, `/mnt/storage/.cursorignore`). It allows normal text/code to be searchable but skips big binaries that cause I/O storms.

`.cursorignore` patterns are relative; don’t use `~` or absolute paths.

Example: apply to a mount root:

```bash
sudo tee /mnt/HDD18T2/.cursorignore < throttle_cursor_vscode/cursorignore-template
sudo tee /mnt/storage/.cursorignore < throttle_cursor_vscode/cursorignore-template
```

Reload Cursor/VSCode after adding (Command/Ctrl–Shift–P → Reload Window).



