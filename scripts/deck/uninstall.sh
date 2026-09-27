#!/usr/bin/env bash
# Removes the XIUI sync service and the addons/XIUI symlink.
# Leaves the clone (~/src/XIUI), the log, XIUI settings, and addons-backup/.
#   bash ~/src/XIUI/scripts/deck/uninstall.sh

GAMEDIR="${XIUI_GAMEDIR:-$HOME/.local/share/Steam/steamapps/compatdata/2799506644/pfx/drive_c/Program Files (x86)/HorizonXI/Game}"
UNITS="$HOME/.config/systemd/user"

systemctl --user disable --now xiui-sync.service 2>/dev/null
rm -f "$UNITS/xiui-sync.service"
systemctl --user daemon-reload

LINK="$GAMEDIR/addons/XIUI"
if [ -L "$LINK" ]; then
    rm "$LINK" && echo "removed symlink $LINK"
fi

echo "sync service removed"
ls "$GAMEDIR/addons-backup" 2>/dev/null && echo "to restore a previous XIUI: mv \"$GAMEDIR/addons-backup/<name>\" \"$LINK\""
