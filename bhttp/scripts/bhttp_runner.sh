#!/usr/bin/env bash
# ==============================================================================
# BHTTP Runner - Wrapper Universal de Ejecución (x86_64 & aarch64)
# WINZAP VPN / Protocolos
# ==============================================================================

CONF_FILE="/etc/bhttp/bhttp.conf"
OPT_DIR="/opt/bhttp"
BIN_FILE="${OPT_DIR}/bin/BHTTP"
RUNTIME_LOADER="${OPT_DIR}/runtime/ld-linux-aarch64.so.1"
RUNTIME_LIBS="${OPT_DIR}/runtime"

# Cargar configuraciones guardadas
if [ -f "$CONF_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONF_FILE"
fi

PORT="${BHTTP_PORT:-2082}"
TARGET="${BHTTP_SSH:-127.0.0.1:22}"

# Si se pasan argumentos manuales por CLI, usarlos; de lo contrario usar los de conf
if [ $# -gt 0 ]; then
    ARGS=("$@")
else
    ARGS=("-listen" "0.0.0.0:${PORT}" "-target" "${TARGET}")
fi

ARCH=$(uname -m)

if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    # Verificar si el binario puede ejecutarse nativamente sin fallos de glibc
    if "${BIN_FILE}" --help >/dev/null 2>&1; then
        exec "${BIN_FILE}" "${ARGS[@]}"
    elif [ -f "$RUNTIME_LOADER" ] && [ -d "$RUNTIME_LIBS" ]; then
        exec "${RUNTIME_LOADER}" --library-path "${RUNTIME_LIBS}" "${BIN_FILE}" "${ARGS[@]}"
    else
        echo "[ERROR] No se pudo ejecutar BHTTP en arquitectura ARM64 y no se encontró el runtime aislado." >&2
        exit 1
    fi
else
    # Arquitectura x86_64
    exec "${BIN_FILE}" "${ARGS[@]}"
fi
