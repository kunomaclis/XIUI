#!/usr/bin/env bash
# One-time Steam Deck setup: clone this repo and install a systemd user
# service that syncs Game/addons/xiui once per login (see xiui-sync.sh).
#   curl -fsSL https://raw.githubusercontent.com/kunomaclis/XIUI/main/scripts/deck/install.sh | bash
# Undo with uninstall.sh. Overrides: XIUI_REPO, XIUI_BRANCH, XIUI_SRC, XIUI_GAMEDIR.

REPO="${XIUI_REPO:-https://github.com/kunomaclis/XIUI.git}"
BRANCH="${XIUI_BRANCH:-main}"
SRC="${XIUI_SRC:-$HOME/src/XIUI}"
UNITS="$HOME/.config/systemd/user"

if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone --recurse-submodules -b "$BRANCH" "$REPO" "$SRC" || { echo "clone failed"; exit 1; }
fi

mkdir -p "$UNITS"
cat > "$UNITS/xiui-sync.service" <<EOF
[Unit]
Description=Sync XIUI addon from git (once per login)

[Service]
Type=oneshot
Environment=XIUI_SRC=$SRC
${XIUI_GAMEDIR:+Environment="XIUI_GAMEDIR=$XIUI_GAMEDIR"}
ExecStart=/usr/bin/bash $SRC/scripts/deck/xiui-sync.sh

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable xiui-sync.service
systemctl --user start xiui-sync.service
echo
tail -n 5 "$HOME/HorizonLogs/xiui-sync.log"
echo
systemctl --user is-enabled xiui-sync.service
