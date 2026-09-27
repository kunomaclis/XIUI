#!/usr/bin/env bash
# Keeps a Steam Deck's HorizonXI addons/XIUI in sync with this repo.
# Fast-forwards the local clone, updates submodules, and (re)links
# Game/addons/XIUI -> <clone>/XIUI. Skips while the game is running.
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
LINK="$ADDONS/XIUI"
TARGET="$SRC/XIUI"
[ -d "$ADDONS" ] || { log "addons dir missing: $ADDONS"; exit 1; }

# Wine paths are case-insensitive, so move aside any other xiui folder
# (e.g. a launcher-installed copy) that would shadow the link.
while IFS= read -r -d '' entry; do
    if [ "$entry" = "$LINK" ] && [ -L "$entry" ]; then continue; fi
    mkdir -p "$GAMEDIR/addons-backup"
    dest="$GAMEDIR/addons-backup/$(basename "$entry").$(date +%Y%m%d-%H%M%S)"
    mv "$entry" "$dest" && log "moved existing $(basename "$entry") to $dest"
done < <(find "$ADDONS" -maxdepth 1 -iname xiui -print0)

if [ "$(readlink "$LINK")" != "$TARGET" ]; then
    ln -sfn "$TARGET" "$LINK" && log "linked $LINK -> $TARGET"
fi
