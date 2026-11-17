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
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuración por defecto
DEFAULT_TOKEN="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"
GITHUB_REPO="wilderusuga514-alt/protocolos"
OPT_DIR="/opt/bhttp"
CONF_DIR="/etc/bhttp"
SERVICE_NAME="bhttp.service"

# Parsear argumentos si se pasan por CLI
TOKEN="${GITHUB_TOKEN:-$DEFAULT_TOKEN}"
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

clear 2>/dev/null || true
echo -e "${CYAN}${BOLD}==================================================================${NC}"
echo -e "          ${BOLD}INSTALADOR UNIVERSAL BHTTP (DTUNNEL / BILOLA)${NC}"
echo -e "                   ${GREEN}WINZAP VPN PROTOCOLOS${NC}"
echo -e "${CYAN}==================================================================${NC}"

# 1. Comprobar permisos root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[✖] Error: Este instalador debe ejecutarse como root (sudo).${NC}"
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

echo -e "${BLUE}[*] Arquitectura detectada:${NC} ${YELLOW}${TARGET_ARCH}${NC} (${RAW_ARCH})"

# 3. Detectar origen de archivos (Local o Descarga remota)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
IS_LOCAL=false
if [ -f "${SCRIPT_DIR}/bhttp/bin/${TARGET_ARCH}/BHTTP" ]; then
    IS_LOCAL=true
    echo -e "${BLUE}[*] Modo de instalación:${NC} ${GREEN}Archivos locales detectados${NC}"
else
    echo -e "${BLUE}[*] Modo de instalación:${NC} ${GREEN}Descarga remota vía GitHub API${NC}"
fi

# 4. Crear estructura de directorios
mkdir -p "${OPT_DIR}/bin"
mkdir -p "${OPT_DIR}/runtime"
mkdir -p "${CONF_DIR}"

# 5. Instalar binario BHTTP
echo -e "${BLUE}[*] Instalando binario para ${TARGET_ARCH}...${NC}"
if [ "$IS_LOCAL" = true ]; then
    cp "${SCRIPT_DIR}/bhttp/bin/${TARGET_ARCH}/BHTTP" "${OPT_DIR}/bin/BHTTP"
else
    DOWNLOAD_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/bhttp/bin/${TARGET_ARCH}/BHTTP"
    curl -H "Authorization: token ${TOKEN}" -fsSL "$DOWNLOAD_URL" -o "${OPT_DIR}/bin/BHTTP"
fi
chmod 755 "${OPT_DIR}/bin/BHTTP"

# 6. Para ARM64: Verificar compatibilidad de GLIBC
if [ "$TARGET_ARCH" = "aarch64" ]; then
    echo -e "${BLUE}[*] Verificando compatibilidad de GLIBC en ARM64...${NC}"
    if "${OPT_DIR}/bin/BHTTP" --help >/dev/null 2>&1; then
        echo -e "${GREEN}[✔] Binario ARM64 compatible nativamente con la versión de GLIBC del sistema.${NC}"
    else
        echo -e "${YELLOW}[!] GLIBC del sistema no compatible directamente. Instalando micro-runtime GLIBC 2.35 aislado...${NC}"
        if [ "$IS_LOCAL" = true ] && [ -f "${SCRIPT_DIR}/bhttp/runtime/aarch64/glibc235.tar.gz" ]; then
            tar -xzf "${SCRIPT_DIR}/bhttp/runtime/aarch64/glibc235.tar.gz" -C "${OPT_DIR}/runtime"
        else
            RUNTIME_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/bhttp/runtime/aarch64/glibc235.tar.gz"
            curl -H "Authorization: token ${TOKEN}" -fsSL "$RUNTIME_URL" -o /tmp/glibc235.tar.gz
            tar -xzf /tmp/glibc235.tar.gz -C "${OPT_DIR}/runtime"
            rm -f /tmp/glibc235.tar.gz
        fi

        # Validar funcionamiento con el runtime
        if [ -f "${OPT_DIR}/runtime/ld-linux-aarch64.so.1" ]; then
            if "${OPT_DIR}/runtime/ld-linux-aarch64.so.1" --library-path "${OPT_DIR}/runtime" "${OPT_DIR}/bin/BHTTP" --help >/dev/null 2>&1; then
                echo -e "${GREEN}[✔] Micro-runtime activado y verificado exitosamente.${NC}"
            else
                echo -e "${RED}[✖] Error crítico: No se pudo ejecutar BHTTP con el runtime.${NC}"
                exit 1
            fi
        fi
    fi
fi

# 7. Instalar scripts auxiliares (runner y menu)
echo -e "${BLUE}[*] Configurando scripts de control...${NC}"
if [ "$IS_LOCAL" = true ]; then
    cp "${SCRIPT_DIR}/bhttp/scripts/bhttp_runner.sh" "${OPT_DIR}/bhttp_runner.sh"
    cp "${SCRIPT_DIR}/bhttp/scripts/bhttp_menu.sh" /usr/local/bin/bhttp
else
    curl -H "Authorization: token ${TOKEN}" -fsSL "https://raw.githubusercontent.com/${GITHUB_REPO}/main/bhttp/scripts/bhttp_runner.sh" -o "${OPT_DIR}/bhttp_runner.sh"
    curl -H "Authorization: token ${TOKEN}" -fsSL "https://raw.githubusercontent.com/${GITHUB_REPO}/main/bhttp/scripts/bhttp_menu.sh" -o /usr/local/bin/bhttp
fi
chmod 755 "${OPT_DIR}/bhttp_runner.sh"
chmod 755 /usr/local/bin/bhttp
ln -sf /usr/local/bin/bhttp /bin/bhttp
ln -sf "${OPT_DIR}/bhttp_runner.sh" /bin/BHTTP

# 8. Selección inteligente de puerto por defecto
DEFAULT_PORT="2082"

# Preservar puerto previo si ya existía configuración o servicio activo
if [ -f "${CONF_DIR}/bhttp.conf" ]; then
    # shellcheck source=/dev/null
    source "${CONF_DIR}/bhttp.conf"
    PORT="${BHTTP_PORT:-$DEFAULT_PORT}"
    TARGET="${BHTTP_SSH:-127.0.0.1:22}"
elif [ -f "/etc/ADMcgh/conf/bhttp.conf" ]; then
    # shellcheck source=/dev/null
    source "/etc/ADMcgh/conf/bhttp.conf"
    PORT="${BHTTP_PORT:-$DEFAULT_PORT}"
    TARGET="127.0.0.1:${BHTTP_SSH:-22}"
else
    # Instalación completamente limpia: si 2082 está ocupado por otro proceso distinto a BHTTP
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
# Configuracion de BHTTP
BHTTP_PORT="${PORT}"
BHTTP_SSH="${TARGET}"
EOF

# Integración con ChumoGH si está presente
if [ -d "/etc/ADMcgh" ]; then
    mkdir -p /etc/ADMcgh/conf
    cat << EOF > /etc/ADMcgh/conf/bhttp.conf
BHTTP_PORT="${PORT}"
BHTTP_SSH="${TARGET#*:}"
EOF
    mkdir -p /etc/ADMcgh/bin
    ln -sf "${OPT_DIR}/bhttp_runner.sh" /etc/ADMcgh/bin/BHTTP
fi

# 9. Crear servicio systemd
echo -e "${BLUE}[*] Configurando servicio del sistema (systemd)...${NC}"
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

# 10. Verificación final
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo -e "\n${GREEN}${BOLD}==================================================================${NC}"
    echo -e "${GREEN}${BOLD}             ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!${NC}"
    echo -e "${GREEN}${BOLD}==================================================================${NC}"
    echo -e " ${BOLD}Protocolo:${NC}      BHTTP (DTunnel / WebSocket)"
    echo -e " ${BOLD}Puerto activo:${NC}  ${YELLOW}${PORT}${NC}"
    echo -e " ${BOLD}Destino SSH:${NC}    ${YELLOW}${TARGET}${NC}"
    echo -e " ${BOLD}Panel de control:${NC} Ejecuta el comando ${CYAN}${BOLD}bhttp${NC} en la terminal"
    echo -e "${GREEN}==================================================================${NC}\n"
else
    echo -e "\n${RED}[✖] El servicio no pudo iniciar automáticamente. Revisa 'journalctl -u bhttp -n 20'${NC}\n"
fi
