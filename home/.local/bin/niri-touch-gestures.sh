#!/usr/bin/env bash
# Gestos multitouch de la pantalla física (touchscreen) para Niri.
# Dispositivo: Wacom HID 48DF Finger, vía lisgd.
# Gestos (solo 3-4 dedos, y 1 dedo desde el borde inferior):
#   3 dedos ← RL → focus-column-right
#   3 dedos → LR → focus-column-left
#   3-4 dedos ↑ → toggle-overview
#   3 dedos ↓   → focus-window-down
#   1 dedo ↑ desde borde inferior → toggle wvkbd
#
# Permisos: /dev/input/event* requiere lectura; regla udev con TAG+="uaccess":
#   SUBSYSTEM=="input", ATTRS{name}=="Wacom HID 48DF Finger", TAG+="uaccess"
#
# Umbrales altos a propósito: no interferir con 1-2 dedos (navegador, Rnote)
# ni con el dibujado con lápiz.
set -u

DEVICE_NAME="Wacom HID 48DF Finger"
OUTPUT="eDP-1"
NIRI_MSG="$HOME/.local/bin/niri-msg.sh"
WVKBD="pkill -x wvkbd-mobintl 2>/dev/null || wvkbd-mobintl -L 280"

THRESHOLD=150    # px mínimos para registrar el gesto (default lisgd: 125)
TIMEOUT_MS=900   # ventana máxima del gesto en ms (default: 400)
DEGREES=25       # tolerancia angular (default: 15)

# Localiza el nodo event* del touchscreen por nombre, sin rutas fijas.
find_device() {
    awk -v RS='' -v name="$DEVICE_NAME" \
        '$0 ~ "Name=\"" name "\"" { match($0, /event[0-9]+/); print "/dev/input/" substr($0, RSTART, RLENGTH); exit }' \
        /proc/bus/input/devices
}

# Transform actual del monitor en niri -> -o de lisgd.
# transform "90" (CCW) -> o=3 ; "270" (CW) -> o=1 ; "180" -> o=2
# Si al rotar las direcciones se sienten invertidas, intercambia 1 y 3.
orientation_from_transform() {
    local t
    t=$("$NIRI_MSG" outputs 2>/dev/null | awk -v out="($OUTPUT)" 'index($0, out) {f=1} f && /Transform:/ {print $2; exit}' | sed 's/°$//')
    case "$t" in
        90)  echo 3 ;;
        270) echo 1 ;;
        180) echo 2 ;;
        *)   echo 0 ;;
    esac
}

setup_display_env() {
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        return 0
    fi
    local candidate
    for candidate in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/wayland-*; do
        [ -S "$candidate" ] || continue
        WAYLAND_DISPLAY="$(basename "$candidate")"
        export WAYLAND_DISPLAY
        break
    done
}

wait_for_niri() {
    local waited=0
    while ! "$NIRI_MSG" version >/dev/null 2>&1; do
        sleep 1
        waited=$((waited + 1))
        if [ $((waited % 30)) -eq 0 ]; then
            echo "niri-touch-gestures: esperando a Niri..." >&2
        fi
    done
}

start_lisgd() {
    local o="$1"
    pkill -x lisgd 2>/dev/null
    sleep 0.2
    lisgd \
        -d "$DEVNODE" \
        -o "$o" \
        -t "$THRESHOLD" \
        -m "$TIMEOUT_MS" \
        -r "$DEGREES" \
        -g "3,RL,*,*,R,$NIRI_MSG action focus-column-right" \
        -g "3,LR,*,*,R,$NIRI_MSG action focus-column-left" \
        -g "3,DU,*,*,R,$NIRI_MSG action toggle-overview" \
        -g "4,DU,*,*,R,$NIRI_MSG action toggle-overview" \
        -g "3,UD,*,*,R,$NIRI_MSG action focus-window-down" \
        -g "1,DU,B,M,R,$WVKBD" \
        &
}

wait_for_niri
setup_display_env

DEVNODE=$(find_device)
if [ -z "$DEVNODE" ]; then
    echo "niri-touch-gestures: dispositivo '$DEVICE_NAME' no encontrado; reintentando..."
    for _ in 1 2 3 4 5; do
        sleep 3
        DEVNODE=$(find_device)
        [ -n "$DEVNODE" ] && break
    done
fi
[ -n "$DEVNODE" ] || { echo "niri-touch-gestures: dispositivo no encontrado, saliendo"; exit 1; }

# Margen para que Niri esté listo al iniciar sesión.
sleep 2

start_lisgd "$(orientation_from_transform)"

# Health check: revive lisgd si muere (p. ej. udev reenumera el event node).
(
    while true; do
        sleep 10
        current_node="$(find_device)"
        if [ -n "$current_node" ] && [ "$current_node" != "$DEVNODE" ]; then
            DEVNODE="$current_node"
            start_lisgd "$(orientation_from_transform)"
        elif ! pgrep -x lisgd >/dev/null 2>&1; then
            start_lisgd "$(orientation_from_transform)"
        fi
    done
) &

# Sigue la rotación con el mismo origen que niri-autorotate.sh y reinicia
# lisgd con la orientación nueva.
monitor-sensor --accel 2>/dev/null | while read -r line; do
    new_o=""
    case "$line" in
        *"orientation changed: normal"*)    new_o=0 ;;
        *"orientation changed: bottom-up"*) new_o=2 ;;
        *"orientation changed: left-up"*)   new_o=3 ;;
        *"orientation changed: right-up"*)  new_o=1 ;;
    esac
    [ -n "$new_o" ] && start_lisgd "$new_o"
done
