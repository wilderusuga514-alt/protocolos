#!/usr/bin/env bash
# ==============================================================================
# Instalador Universal de BHTTP (Bilola DTunnel Protocol)
# Compatible con: x86_64 y ARM64 (Ubuntu 20.04, 22.04, 24.04, Debian 10+)
# WINZAP VPN / Protocolos
# ==============================================================================

set -e
export LC_ALL=C

# Colores ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

GITHUB_REPO="wilderusuga514-alt/protocolos"
OPT_DIR="/opt/bhttp"
CONF_DIR="/etc/bhttp"
SERVICE_NAME="bhttp.service"

TOKEN="${GITHUB_TOKEN:-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --token|-t)
            TOKEN="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

CURL_AUTH=()
if [ -n "$TOKEN" ]; then
    CURL_AUTH=(-H "Authorization: token ${TOKEN}")
fi

clear 2>/dev/null || true
echo -e "${CYAN}${BOLD}==================================================================${NC}"
echo -e "                   ${BOLD}INSTALADOR BHTTP (BILOLA)${NC}"
echo -e "${CYAN}==================================================================${NC}"

# 1. Comprobar permisos root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[✖] Error: Ejecuta este instalador como root (sudo).${NC}"
    exit 1
fi

# 2. Detectar arquitectura
RAW_ARCH=$(uname -m)
case "$RAW_ARCH" in
    x86_64|amd64)
        TARGET_ARCH="x86_64"
        ;;
    aarch64|arm64)
        TARGET_ARCH="aarch64"
        ;;
    *)
        echo -e "${RED}[✖] Arquitectura no soportada: ${RAW_ARCH}${NC}"
        exit 1
        ;;
esac

echo -e " ${GREEN}[✔]${NC} Arquitectura: ${YELLOW}${TARGET_ARCH}${NC}"

# 3. Detectar origen de archivos
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
IS_LOCAL=false
if [ -f "${SCRIPT_DIR}/bhttp/bin/${TARGET_ARCH}/BHTTP" ]; then
    IS_LOCAL=true
fi

# 4. Crear estructura
mkdir -p "${OPT_DIR}/bin" "${OPT_DIR}/runtime" "${CONF_DIR}"

# 5. Instalar binario
echo -e " ${GREEN}[✔]${NC} Instalando binario y dependencias..."
if [ "$IS_LOCAL" = true ]; then
    cp "${SCRIPT_DIR}/bhttp/bin/${TARGET_ARCH}/BHTTP" "${OPT_DIR}/bin/BHTTP"
else
    DOWNLOAD_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/bhttp/bin/${TARGET_ARCH}/BHTTP"
    curl "${CURL_AUTH[@]}" -fsSL "$DOWNLOAD_URL" -o "${OPT_DIR}/bin/BHTTP"
fi
chmod 755 "${OPT_DIR}/bin/BHTTP"

# 6. Para ARM64: Micro-runtime si se requiere
if [ "$TARGET_ARCH" = "aarch64" ]; then
    if ! "${OPT_DIR}/bin/BHTTP" --help >/dev/null 2>&1; then
        if [ "$IS_LOCAL" = true ] && [ -f "${SCRIPT_DIR}/bhttp/runtime/aarch64/glibc235.tar.gz" ]; then
            tar -xzf "${SCRIPT_DIR}/bhttp/runtime/aarch64/glibc235.tar.gz" -C "${OPT_DIR}/runtime"
        else
            RUNTIME_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/bhttp/runtime/aarch64/glibc235.tar.gz"
            curl "${CURL_AUTH[@]}" -fsSL "$RUNTIME_URL" -o /tmp/glibc235.tar.gz
            tar -xzf /tmp/glibc235.tar.gz -C "${OPT_DIR}/runtime"
            rm -f /tmp/glibc235.tar.gz
        fi
    fi
fi

# 7. Scripts auxiliares
if [ "$IS_LOCAL" = true ]; then
    cp "${SCRIPT_DIR}/bhttp/scripts/bhttp_runner.sh" "${OPT_DIR}/bhttp_runner.sh"
    cp "${SCRIPT_DIR}/bhttp/scripts/bhttp_menu.sh" /usr/local/bin/bhttp
else
    curl "${CURL_AUTH[@]}" -fsSL "https://raw.githubusercontent.com/${GITHUB_REPO}/main/bhttp/scripts/bhttp_runner.sh" -o "${OPT_DIR}/bhttp_runner.sh"
    curl "${CURL_AUTH[@]}" -fsSL "https://raw.githubusercontent.com/${GITHUB_REPO}/main/bhttp/scripts/bhttp_menu.sh" -o /usr/local/bin/bhttp
fi
chmod 755 "${OPT_DIR}/bhttp_runner.sh" /usr/local/bin/bhttp
ln -sf /usr/local/bin/bhttp /bin/bhttp
ln -sf "${OPT_DIR}/bhttp_runner.sh" /bin/BHTTP

# 8. Selección inteligente de puerto
DEFAULT_PORT="2082"
if [ -f "${CONF_DIR}/bhttp.conf" ]; then
    source "${CONF_DIR}/bhttp.conf"
    PORT="${BHTTP_PORT:-$DEFAULT_PORT}"
    TARGET="${BHTTP_SSH:-127.0.0.1:22}"
elif [ -f "/etc/ADMcgh/conf/bhttp.conf" ]; then
    source "/etc/ADMcgh/conf/bhttp.conf"
    PORT="${BHTTP_PORT:-$DEFAULT_PORT}"
    TARGET="127.0.0.1:${BHTTP_SSH:-22}"
else
    if ss -tulpn 2>/dev/null | grep -qw ":2082"; then
        if ! ss -tulpn 2>/dev/null | grep -qw ":2052"; then
            DEFAULT_PORT="2052"
        elif ! ss -tulpn 2>/dev/null | grep -qw ":2086"; then
            DEFAULT_PORT="2086"
        fi
    fi
    PORT="$DEFAULT_PORT"
    TARGET="127.0.0.1:22"
fi

cat << EOF > "${CONF_DIR}/bhttp.conf"
BHTTP_PORT="${PORT}"
BHTTP_SSH="${TARGET}"
EOF

if [ -d "/etc/ADMcgh" ]; then
    mkdir -p /etc/ADMcgh/conf /etc/ADMcgh/bin
    cat << EOF > /etc/ADMcgh/conf/bhttp.conf
BHTTP_PORT="${PORT}"
BHTTP_SSH="${TARGET#*:}"
EOF
    ln -sf "${OPT_DIR}/bhttp_runner.sh" /etc/ADMcgh/bin/BHTTP
fi

# 9. Configurar y arrancar servicio
cat << EOF > /etc/systemd/system/${SERVICE_NAME}
[Unit]
Description=BHTTP Bilola Service
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${OPT_DIR}
ExecStart=${OPT_DIR}/bhttp_runner.sh -listen 0.0.0.0:${PORT} -target ${TARGET}
Restart=always
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}" >/dev/null 2>&1
systemctl restart "${SERVICE_NAME}"
sleep 1

echo -e " ${GREEN}[✔]${NC} Servicio configurado y activo en el puerto: ${YELLOW}${PORT}${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo -e " ${BOLD}Instalación completada.${NC} Ejecuta ${CYAN}${BOLD}bhttp${NC} para abrir el panel."
echo -e "${CYAN}==================================================================${NC}\n"
