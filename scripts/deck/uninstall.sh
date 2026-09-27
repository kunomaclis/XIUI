#!/usr/bin/env bash
# Removes the XIUI sync service. Leaves addons/xiui (the last synced copy),
# the clone (~/src/XIUI), the log, XIUI settings, and addons-backup/.
#   bash ~/src/XIUI/scripts/deck/uninstall.sh

GAMEDIR="${XIUI_GAMEDIR:-$HOME/.local/share/Steam/steamapps/compatdata/2799506644/pfx/drive_c/Program Files (x86)/HorizonXI/Game}"
UNITS="$HOME/.config/systemd/user"

systemctl --user disable --now xiui-sync.service 2>/dev/null
rm -f "$UNITS/xiui-sync.service"
systemctl --user daemon-reload

# Links from earlier versions of xiui-sync.sh.
find "$GAMEDIR/addons" -maxdepth 1 -iname xiui -type l -print -delete 2>/dev/null

echo "sync service removed; addons/xiui left as the last synced copy"
ls "$GAMEDIR/addons-backup" 2>/dev/null && echo "to restore a previous XIUI: rm -r \"$GAMEDIR/addons/xiui\" && mv \"$GAMEDIR/addons-backup/<name>\" \"$GAMEDIR/addons/xiui\""
