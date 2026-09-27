#!/usr/bin/env bash
# Keeps a Steam Deck's HorizonXI addons/xiui in sync with this repo.
# Fast-forwards the local clone, updates submodules, and copies <clone>/XIUI
# into Game/addons/xiui. Skips while the game is running.
# Run once per login by the xiui-sync systemd user service; safe to run by hand.

SRC="${XIUI_SRC:-$HOME/src/XIUI}"
GAMEDIR="${XIUI_GAMEDIR:-$HOME/.local/share/Steam/steamapps/compatdata/2799506644/pfx/drive_c/Program Files (x86)/HorizonXI/Game}"
LOG="${XIUI_LOG:-$HOME/HorizonLogs/xiui-sync.log}"

mkdir -p "$(dirname "$LOG")"
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

if pgrep -f horizon-loader.exe >/dev/null; then
    log "game running, skipped"
    exit 0
fi

cd "$SRC" 2>/dev/null || { log "no clone at $SRC"; exit 1; }

before=$(git rev-parse --short HEAD)
# At login the network may not be up yet; retry for up to ~2 minutes.
for try in 1 2 3 4 5 6 7 8 9 10 11 12; do
    git fetch --quiet origin 2>/dev/null && break
    [ "$try" = 12 ] && { log "fetch failed (offline?)"; exit 1; }
    sleep 10
done

# The game may have started while we waited for the network.
if pgrep -f horizon-loader.exe >/dev/null; then
    log "game started during fetch, skipped"
    exit 0
fi
git merge --ff-only --quiet '@{u}' || { log "cannot fast-forward $before (local changes in $SRC?)"; exit 1; }
git submodule update --init --recursive --quiet || { log "submodule update failed"; exit 1; }
after=$(git rev-parse --short HEAD)
[ "$before" != "$after" ] && log "updated $before -> $after"

ADDONS="$GAMEDIR/addons"
DEST="$ADDONS/xiui"
MARK=".xiui-sync"
[ -d "$ADDONS" ] || { log "addons dir missing: $ADDONS"; exit 1; }

# Wine paths are case-insensitive, so any xiui/XIUI entry is the one the game loads.
# Keep only our copy (marked with $MARK); back up anything else once, e.g. the
# launcher-installed folder. Old symlinks from earlier versions are just removed.
while IFS= read -r -d '' entry; do
    if [ -L "$entry" ]; then rm "$entry" && log "removed old link $entry"; continue; fi
    if [ "$entry" = "$DEST" ] && [ -e "$entry/$MARK" ]; then continue; fi
    mkdir -p "$GAMEDIR/addons-backup"
    dest="$GAMEDIR/addons-backup/$(basename "$entry").$(date +%Y%m%d-%H%M%S)"
    mv "$entry" "$dest" && log "moved existing $(basename "$entry") to $dest"
done < <(find "$ADDONS" -maxdepth 1 -iname xiui -print0)

# Copy, not link: HorizonXI client patches can ship addons/xiui and would
# otherwise write into the clone. A patched-over copy is restored next login.
mkdir -p "$DEST"
out=$(rsync -a --delete --itemize-changes --exclude .git --exclude "$MARK" "$SRC/XIUI/" "$DEST/") \
    || { log "rsync failed"; exit 1; }
# Lines starting with '.' are attribute-only (e.g. the dir mtime bumped by touch).
changed=$(printf '%s\n' "$out" | grep -vc -e '^\.' -e '^$')
touch "$DEST/$MARK"
[ "$changed" -gt 0 ] && log "copied $SRC/XIUI -> $DEST ($changed changes)"
exit 0
