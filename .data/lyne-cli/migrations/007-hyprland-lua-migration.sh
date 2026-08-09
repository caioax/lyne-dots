# 007-hyprland-lua-migration.sh - Migrate local Hyprland configs to Lua
#
# Since Hyprland 0.55, hyprlang (.conf) is deprecated in favor of Lua, and the
# git-tracked config (hyprland.conf, conf.d/*.conf) has been replaced by
# hyprland.lua / conf/*.lua via the normal git pull (note: the directory is
# "conf", not "conf.d" - Hyprland's require() treats "." as a path separator,
# so a literal dot in a directory name breaks it). This migration only
# handles the machine-specific files under ~/.config/hypr/ that are NOT
# tracked by git: local/*.conf, monitors.conf and workspaces.conf.
#
# We deliberately do NOT attempt to auto-translate arbitrary hyprlang into
# Lua here - generic translation of binds/dispatchers/effects is easy to get
# subtly wrong and silently break someone's keybinds. Instead we back up the
# old files and drop in fresh Lua templates, then tell you what to port by
# hand.

HYPR_DIR="$HOME/.config/hypr"
BACKUP_DIR="$HYPR_DIR/pre-lua-backup-$(date +%Y%m%d-%H%M%S)"

needs_migration=false
if compgen -G "$HYPR_DIR/local/*.conf" >/dev/null 2>&1; then
    needs_migration=true
fi
[[ -f "$HYPR_DIR/monitors.conf" ]] && needs_migration=true
[[ -f "$HYPR_DIR/workspaces.conf" ]] && needs_migration=true

if [[ "$needs_migration" == false ]]; then
    echo "   No legacy .conf files found in ~/.config/hypr, nothing to migrate"
else
    mkdir -p "$BACKUP_DIR"
    ported_something=false

    # local/*.conf -> back up, replace with fresh .lua templates
    if compgen -G "$HYPR_DIR/local/*.conf" >/dev/null 2>&1; then
        mv "$HYPR_DIR/local"/*.conf "$BACKUP_DIR/"
        echo "   Backed up local/*.conf to $BACKUP_DIR"

        for name in autostart extra_keybinds extra_environment; do
            template="$DOTS_DIR/.data/hyprland/templates/$name.lua"
            dest="$HYPR_DIR/local/$name.lua"
            if [[ -f "$template" && ! -f "$dest" && -f "$BACKUP_DIR/$name.conf" ]]; then
                cp "$template" "$dest"
            fi
        done
        ported_something=true
    fi

    # monitors.conf -> back up, drop in the generic Lua template
    # (re-run 'nwg-displays' afterwards to reconfigure properly)
    if [[ -f "$HYPR_DIR/monitors.conf" ]]; then
        mv "$HYPR_DIR/monitors.conf" "$BACKUP_DIR/"
        if [[ ! -f "$HYPR_DIR/monitors.lua" ]]; then
            cp "$DOTS_DIR/.data/hyprland/templates/monitors.lua" "$HYPR_DIR/monitors.lua"
        fi
        echo "   monitors.conf backed up; wrote generic monitors.lua (run nwg-displays to reconfigure)"
        ported_something=true
    fi

    # workspaces.conf -> just back up and remove; workspace-manager.sh
    # regenerates workspaces.lua automatically on next boot
    if [[ -f "$HYPR_DIR/workspaces.conf" ]]; then
        mv "$HYPR_DIR/workspaces.conf" "$BACKUP_DIR/"
        echo "   workspaces.conf backed up; workspace-manager.sh will regenerate workspaces.lua on next boot"
        ported_something=true
    fi

    if [[ "$ported_something" == true ]]; then
        echo ""
        echo "   ⚠ Old configs were backed up, NOT auto-translated to Lua."
        echo "   ⚠ Port any customizations from:"
        echo "       $BACKUP_DIR"
        echo "     into:"
        echo "       ~/.config/hypr/local/autostart.lua"
        echo "       ~/.config/hypr/local/extra_environment.lua"
        echo "       ~/.config/hypr/local/extra_keybinds.lua"
        echo "   ⚠ See https://wiki.hypr.land/Configuring/Start/ for Lua syntax."
    fi
fi
