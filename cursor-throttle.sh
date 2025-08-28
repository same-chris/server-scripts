#!/usr/bin/env bash
set -euo pipefail

# Targets: Cursor's own binaries only (under ~/.cursor-server)
FIND_CURSOR_DIRS='find /home -maxdepth 2 -type d -name ".cursor-server" 2>/dev/null'
FIND_BINS(){ 
  # node binaries + bundled ripgrep binaries
  eval "$FIND_CURSOR_DIRS" | while read -r cs; do
    find "$cs" -type f -perm -111 \( -name node -o -path '*/node_modules/@vscode/ripgrep/bin/rg' \) 2>/dev/null
  done
}

WRAPPER_CONTENT='#!/usr/bin/env bash
set -e
real="$(dirname "$0")/$(basename "$0").real"
exec ionice -c3 nice -n 19 "$real" "$@"'

apply() {
  local changed=0
  while IFS= read -r bin; do
    [ -e "$bin.real" ] && continue
    mv "$bin" "$bin.real"
    printf '%s\n' "$WRAPPER_CONTENT" > "$bin"
    chmod +x "$bin"
    echo "wrapped: $bin"
    changed=1
  done < <(FIND_BINS)
  [ "$changed" -eq 0 ] && echo "nothing to wrap (already applied?)"
}

restore() {
  local changed=0
  eval "$FIND_CURSOR_DIRS" | while read -r cs; do
    find "$cs" -type f -perm -111 \( -name 'node.real' -o -name 'rg.real' \) 2>/dev/null | while read -r real; do
      mv -f "$real" "${real%.real}"
      echo "restored: ${real%.real}"
      changed=1
    done
  done
  [ "$changed" -eq 0 ] && echo "nothing to restore"
}

status() {
  echo "Wrapped binaries:"
  eval "$FIND_CURSOR_DIRS" | while read -r cs; do
    find "$cs" -type f -name '*.real' 2>/dev/null | sed 's/\.real$//'
  done | sed 's/^/  /' || true
  echo
  echo "Running Cursor processes (check ionice=idle, nice=19):"
  pgrep -af '/\.cursor-server/.*(node|ripgrep/bin/rg)' || true
}

usage(){ echo "Usage: $0 {apply|restore|status}"; exit 1; }

case "${1:-}" in
  apply)   apply   ;;
  restore) restore ;;
  status)  status  ;;
  *) usage ;;
esac
