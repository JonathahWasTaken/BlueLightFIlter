#!/system/bin/sh
# Installation and upgrade migration for Magisk/KernelSU module managers.

MODULE_ID=bluelightfilter
LIVE_MODDIR=/data/adb/modules/$MODULE_ID
CONFIG_DEST=$MODPATH/config.conf

ui_print ""
ui_print "============================================"
ui_print "   BlueLightFIlter 2.0.1"
ui_print "   SurfaceFlinger color transforms"
ui_print "============================================"
ui_print ""

SDK=${API:-$(getprop ro.build.version.sdk 2>/dev/null)}
ui_print "  Android API: ${SDK:-unknown}"
if [ -n "$SDK" ] && [ "$SDK" -lt 26 ]; then
    abort "  Android 8.0 (API 26) or newer is required."
fi

if [ ! -x /system/bin/service ]; then
    ui_print "  [WARNING] /system/bin/service is unavailable."
    ui_print "  The module can install, but the filter may not work on this ROM."
fi

# Magisk boot-mode updates are staged in modules_update. Copy only durable,
# known state from the live module; never carry PID, lock, or schedule-owner files.
if [ "$MODPATH" != "$LIVE_MODDIR" ] && [ -d "$LIVE_MODDIR" ]; then
    for name in config.conf autoboot enabled .installed; do
        [ -f "$LIVE_MODDIR/$name" ] && cp -f "$LIVE_MODDIR/$name" "$MODPATH/$name"
    done
    ui_print "  Existing settings copied into the staged update."
fi

[ -f "$CONFIG_DEST" ] || abort "  Bundled configuration is missing."
[ -r "$MODPATH/system/bin/bluefilter-core" ] || abort "  Shared filter core is missing."

. "$MODPATH/system/bin/bluefilter-core"
if ! migrate_config "$CONFIG_DEST"; then
    abort "  Configuration migration failed."
fi
if ! config_is_valid "$CONFIG_DEST"; then
    cp -f "$CONFIG_DEST" "$MODPATH/config.conf.invalid"
    unzip -p "$ZIPFILE" config.conf > "$CONFIG_DEST" || abort "  Could not restore safe defaults."
    ui_print "  Invalid configuration backed up as config.conf.invalid."
fi

if [ ! -f "$MODPATH/.installed" ]; then
    rm -f "$MODPATH/enabled" "$MODPATH/autoboot"
    : > "$MODPATH/.installed"
    ui_print "  Fresh install: filter and auto-start are disabled."
else
    ui_print "  Upgrade: profile, schedule, notification, and boot settings preserved."
fi

rm -f "$MODPATH/.auto_enabled" "$MODPATH/.manual_off" "$MODPATH/daemon.pid"
rm -f "$MODPATH/.bluefilter.lock/pid" 2>/dev/null
rmdir "$MODPATH/.bluefilter.lock" 2>/dev/null

set_perm "$MODPATH/system/bin/bluefilter" 0 0 0755
set_perm "$MODPATH/system/bin/bluefilter-daemon" 0 0 0755
set_perm "$MODPATH/system/bin/bluefilter-core" 0 0 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$CONFIG_DEST" 0 0 0600
set_perm_recursive "$MODPATH/webroot" 0 0 0755 0644

ui_print ""
ui_print "  Installation complete. Reboot before use."
ui_print ""
