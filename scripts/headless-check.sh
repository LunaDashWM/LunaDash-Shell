#!/usr/bin/env bash
# Runs the shell inside a private headless sway, opens every overlay and popup through the
# SlintLu IPC socket and fails if the shell dies. Screenshots go to $SHOTS (default: none).
#
# Usage: scripts/headless-check.sh [shell-dir]      Needs: sway, grim, slintlu, dbus.
set -euo pipefail

if [[ -z "${LUNADASH_PRIVATE_BUS:-}" ]] && command -v dbus-run-session >/dev/null; then
    export LUNADASH_PRIVATE_BUS=1
    exec dbus-run-session -- "$0" "$@"
fi

shell_dir=$(realpath "${1:-.}")
slintlu=${SLINTLU:-slintlu}
shots=${SHOTS:-}
[[ -n $shots ]] && mkdir -p "$shots"

# Short path: Unix socket paths are limited to 108 bytes.
work=$(mktemp -d /tmp/ld-check.XXXX)
export XDG_RUNTIME_DIR=$work/rt XDG_STATE_HOME=$work/state XDG_CONFIG_HOME=$work/config XDG_CACHE_HOME=$work/cache
mkdir -m 700 "$XDG_RUNTIME_DIR"
pids=()
cleanup() {
    for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    wait 2>/dev/null || true
    rm -rf "$work"
}
trap cleanup EXIT

fail() {
    echo "::error title=headless check::$1"
    grep -v '^\s' "$work/shell.log" | tail -n 20 >&2 || true
    exit 1
}

printf 'output HEADLESS-1 resolution 1600x900 background #000000 solid_color\ndefault_border none\n' > "$work/sway.conf"
env -u WAYLAND_DISPLAY -u DISPLAY WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
    sway --unsupported-gpu -c "$work/sway.conf" >"$work/sway.log" 2>&1 &
pids+=($!)
for _ in $(seq 100); do
    socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -print -quit)
    [[ -n $socket ]] && break
    sleep 0.1
done
[[ -n ${socket:-} ]] || { cat "$work/sway.log"; fail "sway did not start"; }
export WAYLAND_DISPLAY=$(basename "$socket")
export SWAYSOCK=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'sway-ipc.*' -print -quit)
export XDG_CURRENT_DESKTOP=sway
unset NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE I3SOCK LUNADASH_CONTROL

# A PAM service that does not exist: the lock screen can never check a real password here.
SLINTLU_PAM_SERVICE=lunadash-check-nonexistent SLINTLU_RENDERER=software RUST_LOG=info \
    "$slintlu" --no-reload --config "$shell_dir" >"$work/shell.log" 2>&1 &
shell=$!
pids+=($shell)
sleep "${SETTLE_SECONDS:-5}"

step() {
    sleep 1.2
    kill -0 "$shell" 2>/dev/null || fail "the shell died after: $1"
    [[ -z $shots ]] || grim "$shots/$1.png"
    echo "ok: $1"
}
msg() { "$slintlu" msg "$@" >/dev/null || fail "IPC failed: $*"; }

step startup
[[ $("$slintlu" msg call Shared.get-string overlay "" 0) == welcome ]] || fail "the welcome card did not open"
msg call Store.set-bool welcome-done true
for overlay in dashboard launcher settings gallery power ""; do
    msg call Shared.set-string overlay "$overlay"
    step "overlay-${overlay:-none}"
done
for tab in 1 2 3; do
    msg call Shared.set-number dashboard-tab $tab
    msg call Shared.set-string overlay dashboard
    step "dashboard-tab-$tab"
done
msg call Shared.set-string overlay ""
for popup in calendar audio network clipboard ""; do
    msg call Shared.set-string popup "$popup"
    step "popup-${popup:-none}"
done
# The desktop menu, at the pointer position a right click would give, on the first screen.
screen=$("$slintlu" msg get Shell.screen | sed -n 's/.*"name": "\(.*\)".*/\1/p' | head -n1)
msg call Shared.set-string desktop-menu-screen "$screen"
msg call Shared.set-number desktop-menu-x 400
msg call Shared.set-number desktop-menu-y 300
msg call Shared.set-string popup desktop-menu
step desktop-menu
msg call Shared.set-string popup ""
msg call Shared.set-string settings-page menu
msg call Shared.set-string overlay settings
step settings-desktop-menu
msg call Shared.set-string overlay ""
msg call I18n.set-language zh_TW
msg call Shared.set-string overlay settings
step "settings-zh_TW"
msg call Shared.set-string overlay ""
if command -v notify-send >/dev/null && [[ $("$slintlu" msg get Notifications.available) == true ]]; then
    notify-send -a "LunaDash check" "Hello" "from the headless check"
    step notification
fi
msg call Session.lock
step lock
[[ $("$slintlu" msg get Session.locked) == true ]] || fail "the session did not lock"
echo "headless check passed"
