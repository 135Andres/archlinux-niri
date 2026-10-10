#!/usr/bin/env bash
# Gestor de inactividad/energía para Niri (HP ZBook Studio x360 G5).
# Gestionado por niri-power-manager.service (systemd user).
#
# CONECTADO (AC online=1):
#   60 min  -> bloqueo de pantalla (la pantalla SIGUE encendida)
#   120 min -> apagado de pantalla
#   (sin suspensión)
#
# SIN CONEXIÓN (batería):
#   15 min  -> bloqueo de pantalla
#   20 min  -> apagado de pantalla
#   25 min  -> suspensión del equipo
#
# Al conectar/desconectar el cargador los temporizadores se reinician con
# el perfil correspondiente. Cada evento se dispara por inactividad del
# usuario (swayidle); cualquier actividad cancela la cuenta atrás.
#
# Nota: no se usa `swayidle -w` (esperar comando) porque la pantalla de
# bloqueo no termina hasta desbloquear, lo que bloquearía los eventos
# posteriores (apagado y suspensión nunca se ejecutarían).
set -u

NIRI_MSG="$HOME/.local/bin/niri-msg.sh"
AC_FILE="/sys/class/power_supply/AC/online"
# Pantalla de bloqueo: la de Caelestia Shell.
# La CLI requiere target + función: `caelestia shell lock lock`.
LOCK="caelestia shell lock lock"
POWER_OFF="$NIRI_MSG action power-off-monitors"
POWER_ON="$NIRI_MSG action power-on-monitors"
SUSPEND="/usr/bin/systemctl suspend"

# FORCE_PROFILE=ac|bat permite probar un perfil sin esperar el cambio real.
ac_online() {
    [ "${FORCE_PROFILE:-}" = "ac" ] && return 0
    [ "${FORCE_PROFILE:-}" = "bat" ] && return 1
    [ "$(cat "$AC_FILE" 2>/dev/null)" = "1" ]
}

swayidle_pid=""

stop_swayidle() {
    [ -n "$swayidle_pid" ] && kill "$swayidle_pid" 2>/dev/null
    pkill -x swayidle 2>/dev/null
    swayidle_pid=""
}

start_swayidle() {
    stop_swayidle
    if ac_online; then
        echo "power-manager: perfil CONECTADO -> bloqueo 60 min, apagar pantalla 120 min"
        swayidle \
            timeout 3600 "$LOCK" \
            timeout 7200 "$POWER_OFF" \
            resume "$POWER_ON" \
            before-sleep "$LOCK" &
    else
        echo "power-manager: perfil BATERÍA -> bloqueo 15 min, apagar pantalla 20 min, suspender 25 min"
        swayidle \
            timeout 900 "$LOCK" \
            timeout 1200 "$POWER_OFF" \
            timeout 1500 "$SUSPEND" \
            resume "$POWER_ON" \
            before-sleep "$LOCK" &
    fi
    swayidle_pid=$!
}

trap 'stop_swayidle; exit 0' INT TERM
trap stop_swayidle EXIT

if ac_online; then last_state="ac"; else last_state="bat"; fi
start_swayidle

# Reacciona a conexión/desconexión del cargador (polling de sysfs).
while true; do
    sleep 3
    if ac_online; then
        state="ac"
    else
        state="bat"
    fi
    if [ "$state" != "${last_state:-}" ]; then
        echo "power-manager: estado de alimentación -> $state (reiniciando temporizadores)"
        start_swayidle
        last_state="$state"
    fi
done
