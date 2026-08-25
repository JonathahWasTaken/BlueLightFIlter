#!/usr/bin/env sh
set -u

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
group=${1:-all}
status=0

run_group() {
    name=$1
    file="$ROOT/tests/test-$name.sh"
    [ -f "$file" ] || return 0
    printf '\n[%s]\n' "$name"
    sh "$file" || status=1
}

case "$group" in
    all)
        for name in core cli automation webui packaging; do
            run_group "$name"
        done
        ;;
    core|cli|automation|webui|packaging) run_group "$group" ;;
    *) printf 'Unknown test group: %s\n' "$group" >&2; exit 2 ;;
esac

exit "$status"
