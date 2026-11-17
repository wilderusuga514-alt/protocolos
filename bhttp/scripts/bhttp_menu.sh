#!/usr/bin/env bash
# ==============================================================================
# Panel de Control BHTTP (DTunnel / Bilola)
# WINZAP VPN / Protocolos
# ==============================================================================

export LC_ALL=C
CONF_FILE="/etc/bhttp/bhttp.conf"
SERVICE_NAME="bhttp.service"

# Colores ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[!] Debes ejecutar este panel como root (sudo bhttp)${NC}"
        exit 1
    fi
}

load_config() {
    if [ -f "$CONF_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONF_FILE"
    fi
    PORT="${BHTTP_PORT:-2082}"
    TARGET="${BHTTP_SSH:-127.0.0.1:22}"
}

save_config() {
    mkdir -p /etc/bhttp
    cat << EOF > "$CONF_FILE"
# Configuracion de BHTTP
BHTTP_PORT="${PORT}"
BHTTP_SSH="${TARGET}"
EOF

    # Compatibilidad con ChumoGH si existe
    if [ -d "/etc/ADMcgh/conf" ]; then
        cat << EOF > /etc/ADMcgh/conf/bhttp.conf
BHTTP_PORT="${PORT}"
BHTTP_SSH="${TARGET#*:}"
EOF
    fi

    # Actualizar systemd service
    cat << EOF > /etc/systemd/system/${SERVICE_NAME}
[Unit]
Description=BHTTP Bilola Service
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/bhttp
ExecStart=/opt/bhttp/bhttp_runner.sh -listen 0.0.0.0:${PORT} -target ${TARGET}
Restart=always
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

get_status() {
    ARCH=$(uname -m)
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        STATUS_LABEL="${GREEN}${BOLD}ACTIVO / EN LÍNEA${NC}"
        PID=$(systemctl show --property MainPID --value "$SERVICE_NAME")
        if [ "$PID" -gt 0 ] 2>/dev/null; then
            MEM=$(ps -o rss= -p "$PID" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
            [ -z "$MEM" ] && MEM="N/A"
        else
            MEM="N/A"
        fi
    else
        STATUS_LABEL="${RED}${BOLD}DETENIDO / INACTIVO${NC}"
        PID="---"
        MEM="---"
    fi
}

check_port_collision() {
    local check_p="$1"
    local collision
    collision=$(ss -tulpn 2>/dev/null | grep -w ":${check_p}" || true)
    if [ -n "$collision" ]; then
        echo "$collision"
        return 1
    fi
    return 0
}

header() {
    clear 2>/dev/null || true
    load_config
    get_status
    echo -e "${CYAN}${BOLD}==================================================================${NC}"
    echo -e "                   ${BOLD}WINZAP - PANEL DE CONTROL BHTTP${NC}"
    echo -e "${CYAN}==================================================================${NC}"
    echo -e " ${BOLD}Protocolo:${NC}      BHTTP (DTunnel / WebSocket -> SSH)"
    echo -e " ${BOLD}Arquitectura:${NC}   ${YELLOW}${ARCH}${NC}"
    echo -e " ${BOLD}Estado:${NC}         ${STATUS_LABEL}"
    echo -e " ${BOLD}Puerto Escucha:${NC} ${GREEN}${PORT}${NC}"
    echo -e " ${BOLD}Destino SSH:${NC}    ${TARGET}"
    echo -e " ${BOLD}PID:${NC}            ${PID}   |   ${BOLD}Memoria:${NC} ${MEM}"
    echo -e "${CYAN}==================================================================${NC}"
}

menu() {
    while true; do
        header
        echo -e "  ${YELLOW}[1]${NC} Iniciar / Reiniciar BHTTP"
        echo -e "  ${YELLOW}[2]${NC} Detener BHTTP"
        echo -e "  ${YELLOW}[3]${NC} Cambiar Puerto de Escucha (Actual: ${GREEN}${PORT}${NC})"
        echo -e "  ${YELLOW}[4]${NC} Cambiar Puerto SSH Destino (Actual: ${GREEN}${TARGET}${NC})"
        echo -e "  ${YELLOW}[5]${NC} Ver Logs en Tiempo Real"
        echo -e "  ${YELLOW}[6]${NC} Probar Conexión Local (Handshake DTunnel)"
        echo -e "  ${YELLOW}[7]${NC} Desinstalar BHTTP"
        echo -e "  ${RED}[0]${NC} Salir"
        echo -e "${CYAN}==================================================================${NC}"
        read -rp " Selecciona una opción [0-7]: " opt

        case "$opt" in
            1)
                echo -e "\n${BLUE}[*] Iniciando / Reiniciando BHTTP...${NC}"
                save_config
                systemctl restart "$SERVICE_NAME"
                sleep 1
                if systemctl is-active --quiet "$SERVICE_NAME"; then
                    echo -e "${GREEN}[✔] BHTTP se inició exitosamente en el puerto ${PORT}.${NC}"
                else
                    echo -e "${RED}[✖] Error al iniciar BHTTP. Revisa los logs con la opción [5].${NC}"
                fi
                read -rp "Presiona [Enter] para continuar..."
                ;;
            2)
                echo -e "\n${BLUE}[*] Deteniendo BHTTP...${NC}"
                systemctl stop "$SERVICE_NAME"
                sleep 1
                echo -e "${YELLOW}[!] BHTTP ha sido detenido.${NC}"
                read -rp "Presiona [Enter] para continuar..."
                ;;
            3)
                echo -e "\n${CYAN}--- Cambiar Puerto de Escucha ---${NC}"
                echo -e "Puertos recomendados compatibles con Cloudflare: ${GREEN}2082, 2052, 2086, 2095, 8880, 8080, 80${NC}"
                read -rp "Ingresa el nuevo puerto: " new_port
                if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
                    echo -e "${RED}[✖] Puerto inválido. Debe ser un número entre 1 y 65535.${NC}"
                    read -rp "Presiona [Enter] para continuar..."
                    continue
                fi

                # Verificar si ya está en uso por otro servicio
                col=$(check_port_collision "$new_port")
                if [ -n "$col" ]; then
                    echo -e "\n${RED}[⚠️ ADVERTENCIA] El puerto ${new_port} ya está en uso en el sistema:${NC}"
                    echo -e "${YELLOW}${col}${NC}"
                    read -rp "¿Deseas asignarlo de todas formas? (s/N): " force_use
                    if [[ ! "$force_use" =~ ^[sS]$ ]]; then
                        echo -e "${YELLOW}[*] Operación cancelada.${NC}"
                        read -rp "Presiona [Enter] para continuar..."
                        continue
                    fi
                fi

                PORT="$new_port"
                save_config
                systemctl restart "$SERVICE_NAME"
                sleep 1
                echo -e "${GREEN}[✔] Puerto actualizado a ${PORT} y servicio reiniciado.${NC}"
                read -rp "Presiona [Enter] para continuar..."
                ;;
            4)
                echo -e "\n${CYAN}--- Cambiar Puerto SSH Destino ---${NC}"
                read -rp "Ingresa el destino SSH (Ej: 127.0.0.1:22): " new_target
                if [ -z "$new_target" ]; then
                    echo -e "${RED}[✖] Destino no puede estar vacío.${NC}"
                    read -rp "Presiona [Enter] para continuar..."
                    continue
                fi
                TARGET="$new_target"
                save_config
                systemctl restart "$SERVICE_NAME"
                sleep 1
                echo -e "${GREEN}[✔] Destino SSH actualizado a ${TARGET}.${NC}"
                read -rp "Presiona [Enter] para continuar..."
                ;;
            5)
                echo -e "\n${BLUE}[*] Mostrando logs en vivo (Presiona Ctrl + C para volver al menú)...${NC}\n"
                sleep 1
                journalctl -u "$SERVICE_NAME" -f -n 25 --no-pager
                read -rp "Presiona [Enter] para volver al menú..."
                ;;
            6)
                echo -e "\n${BLUE}[*] Probando conexión local DTunnel en 127.0.0.1:${PORT}...${NC}"
                if command -v python3 >/dev/null 2>&1; then
                    python3 -c "
import socket
s = socket.socket()
s.settimeout(3)
try:
    s.connect(('127.0.0.1', ${PORT}))
    s.sendall(b'GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n')
    data = s.recv(512)
    print('\033[0;32m[✔] RESPUESTA RECIBIDA CON ÉXITO:\033[0m')
    print(data.decode('utf-8', errors='ignore'))
except Exception as e:
    print('\033[0;31m[✖] ERROR EN LA CONEXIÓN:\033[0m', e)
finally:
    s.close()
"
                else
                    curl -i -m 3 -H "Upgrade: websocket" -H "Connection: Upgrade" "http://127.0.0.1:${PORT}/" || true
                fi
                read -rp "Presiona [Enter] para continuar..."
                ;;
            7)
                echo -e "\n${RED}==================================================================${NC}"
                echo -e "${RED}${BOLD}                       DESINSTALACIÓN BHTTP${NC}"
                echo -e "${RED}==================================================================${NC}"
                read -rp "¿Estás COMPLETAMENTE seguro de desinstalar BHTTP? (s/N): " confirm
                if [[ "$confirm" =~ ^[sS]$ ]]; then
                    echo -e "\n${YELLOW}[*] Deteniendo y eliminando servicio...${NC}"
                    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
                    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
                    rm -f "/etc/systemd/system/${SERVICE_NAME}"
                    systemctl daemon-reload

                    echo -e "${YELLOW}[*] Eliminando binarios y archivos de configuración...${NC}"
                    rm -rf /opt/bhttp
                    rm -rf /etc/bhttp
                    rm -f /usr/local/bin/bhttp
                    rm -f /bin/bhttp

                    echo -e "${GREEN}[✔] BHTTP ha sido desinstalado correctamente de la VPS.${NC}"
                    exit 0
                else
                    echo -e "${YELLOW}[*] Desinstalación cancelada.${NC}"
                    read -rp "Presiona [Enter] para continuar..."
                fi
                ;;
            0)
                clear 2>/dev/null || true
                echo -e "${GREEN}¡Hasta pronto! Puedes volver a abrir este panel escribiendo 'bhttp'.${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}[!] Opción no válida.${NC}"
                sleep 1
                ;;
        esac
    done
}

check_root
menu
