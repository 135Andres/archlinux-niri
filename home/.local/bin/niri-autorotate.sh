#!/usr/bin/env bash
# Auto-rotación de pantalla para HP ZBook Studio x360 G5 en Niri.
# Gestionado por el servicio systemd user niri-autorotate.service.
set -u

OUTPUT="eDP-1"
NIRI_MSG="$HOME/.local/bin/niri-msg.sh"
SENSOR_DEST="net.hadess.SensorProxy"
SENSOR_PATH="/net/hadess/SensorProxy"

orientation_now() {
  gdbus call --system \
    --dest "$SENSOR_DEST" \
    --object-path "$SENSOR_PATH" \
    --method org.freedesktop.DBus.Properties.Get \
    net.hadess.SensorProxy AccelerometerOrientation 2>/dev/null \
    | sed -n "s/.*'\([^']*\)'.*/\1/p"
}

transform_for_orientation() {
  case "$1" in
    normal)    echo normal ;;
    bottom-up) echo 180 ;;
    left-up)   echo 90 ;;
    right-up)  echo 270 ;;
    *)         echo "" ;;
  esac
}

wait_for_niri() {
  local waited=0
  while ! "$NIRI_MSG" version >/dev/null 2>&1; do
    sleep 1
    waited=$((waited + 1))
    if [ $((waited % 30)) -eq 0 ]; then
      echo "niri-autorotate: esperando a Niri..." >&2
    fi
  done
}

# La propiedad D-Bus del proxy es más fiable que monitor-sensor para
# recuperar la orientación natural: no se pierde el evento si el pipeline
# se reconecta o si el sensor emite el estado inicial.
wait_for_niri

while :; do
  orientation="$(orientation_now)"
  new_transform="$(transform_for_orientation "$orientation")"
  actual_transform=$("$NIRI_MSG" outputs 2>/dev/null | awk -v out="($OUTPUT)" 'index($0, out) {f=1} f && /Transform:/ {print $2; exit}' | sed 's/°$//')

  if [ -n "$new_transform" ] && [ "$new_transform" != "$actual_transform" ]; then
    printf 'niri-autorotate: sensor=%s transform=%s -> %s\n' "$orientation" "$actual_transform" "$new_transform" >&2
    "$NIRI_MSG" output "$OUTPUT" transform "$new_transform" 2>/dev/null || true
  fi

  sleep 0.5
done
