#!/usr/bin/env bash
# Wrapper de `niri msg` que descubre el socket actual de Niri cada vez.
# Necesario para servicios systemd user: el NIRI_SOCKET del entorno puede
# quedar obsoleto si Niri se reinicia (el nombre incluye el PID).
# Niri usa normalmente niri.wayland-<display>.<pid>.sock, pero versiones
# anteriores usaban niri.wayland.<pid>.sock; aceptamos ambas formas.
sock=$(ls -t "${XDG_RUNTIME_DIR}"/niri.wayland*.sock 2>/dev/null | head -n1)
[ -n "$sock" ] && export NIRI_SOCKET="$sock"
exec niri msg "$@"
