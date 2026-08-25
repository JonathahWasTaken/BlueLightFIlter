#!/system/bin/sh
# Late-start boot hook for Magisk, KernelSU, and compatible module managers.

MODDIR=${0%/*}
CLI=/system/bin/bluefilter
SERVICE=/system/bin/service
GETPROP=/system/bin/getprop

# Boot has a bounded wait so this script never remains resident forever.
attempt=0
while [ "$($GETPROP sys.boot_completed 2>/dev/null)" != 1 ] && [ "$attempt" -lt 180 ]; do
    attempt=$((attempt + 1))
    sleep 2
done

# SurfaceFlinger may become reachable shortly after boot-completed.
attempt=0
surfaceflinger_ready=0
while [ "$attempt" -lt 60 ]; do
    result=$($SERVICE check SurfaceFlinger 2>&1)
    case "$result" in
        *'not found'*) ;;
        *) surfaceflinger_ready=1; break ;;
    esac
    attempt=$((attempt + 1))
    sleep 1
done

# Runtime state never survives a compositor restart by itself.
rm -f "$MODDIR/enabled" "$MODDIR/.auto_enabled" "$MODDIR/.manual_off" "$MODDIR/daemon.pid"

[ "$surfaceflinger_ready" -eq 1 ] || exit 0

if [ -f "$MODDIR/autoboot" ]; then
    "$CLI" _boot-on >/dev/null 2>&1
fi

# An enabled schedule can supersede an inactive boot state, but never a
# successfully restored autoboot state it does not own.
"$CLI" schedule evaluate >/dev/null 2>&1
"$CLI" daemon-reconcile >/dev/null 2>&1

exit 0
