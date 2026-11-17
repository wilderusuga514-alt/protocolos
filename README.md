# 🚀 WINZAP PROTOCOLOS - BHTTP (Bilola DTunnel)

Repositorio oficial y modular de protocolos para servidores VPS Linux. Diseñado para ser **100% independiente**, universal y compatible tanto con arquitecturas **x86_64** (Intel/AMD) como **ARM64 / aarch64** (Oracle Cloud Ampere, Raspberry Pi, AWS Graviton, etc.).

---

## 📋 Características

- ⚡ **Instalación en 1 solo paso**: Detección automática de arquitectura (`x86_64` o `ARM64`) y sistema operativo.
- 🛡️ **Compatibilidad Oracle Cloud ARM64**: Integra un micro-runtime aislado de GLIBC 2.35 (menos de 1 MB) que resuelve el error `version GLIBC_2.34 not found` en Ubuntu 20.04 sin modificar las librerías de tu servidor ni poner en riesgo otros servicios (como PostgreSQL, Nginx, Python o el Banker).
- 🎛️ **Panel de control interactivo**: Puedes abrir el panel en cualquier momento simplemente escribiendo `bhttp` en tu terminal.
- 🔄 **Convivencia con ChumoGH**: Si tu VPS ya tiene instalado el script de Chumo, se sincroniza automáticamente con él en `/etc/ADMcgh/` sin sobreescribir ni romper los demás protocolos.
- 🌐 **Compatibilidad Cloudflare**: Funciona con puertos HTTP estándar (2082, 2052, 2086, 2095, 8880, 8080) para túneles y payloads DTunnel / WebSocket.

---

## 📥 Instalación Rápida (1 Solo Comando)

Copia y pega este comando en la terminal de tu VPS (como `root` o con `sudo`):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wilderusuga514-alt/protocolos/main/install.sh)
```

O si prefieres clonar el repositorio:

```bash
git clone https://github.com/wilderusuga514-alt/protocolos.git
cd protocolos
sudo bash install.sh
```

---

## 🎛️ Panel de Control (`bhttp`)

Una vez instalado, puedes abrir el menú de administración escribiendo:

```bash
bhttp
```

### Opciones disponibles en el panel:

```text
==================================================================
                   WINZAP - PANEL DE CONTROL BHTTP
==================================================================
 Protocolo:      BHTTP (DTunnel / WebSocket -> SSH)
 Arquitectura:   aarch64
 Estado:         ACTIVO / EN LÍNEA
 Puerto Escucha: 2082
 Destino SSH:    127.0.0.1:22
 PID:            2498897   |   Memoria: 1.1 MB
==================================================================
  [1] Iniciar / Reiniciar BHTTP
  [2] Detener BHTTP
  [3] Cambiar Puerto de Escucha (Actual: 2082)
  [4] Cambiar Puerto SSH Destino (Actual: 127.0.0.1:22)
  [5] Ver Logs en Tiempo Real
  [6] Probar Conexión Local (Handshake DTunnel)
  [7] Desinstalar BHTTP
  [0] Salir
==================================================================
```

---

## 🔌 Configuración de Puertos y Cloudflare

BHTTP responde a peticiones WebSocket y HTTP tipo `DTunnel`. Si utilizas Cloudflare CDN, los siguientes puertos HTTP están soportados:

| Puerto | Estado común en VPS | Compatible Cloudflare |
| :---: | :---: | :---: |
| **`2082`** | **Libre por defecto (Recomendado)** | ✅ Sí |
| **`2052`** | Libre | ✅ Sí |
| **`2086`** | Libre | ✅ Sí |
| **`2095`** | Libre | ✅ Sí |
| **`8880`** | Ocupado por Caddy en VPS Oracle / Libre en Miami | ✅ Sí |
| **`8080`** | Ocupado por Proxy HTTP en algunas VPS | ✅ Sí |

El panel de control incluye detección automática de colisiones: si intentas usar un puerto que ya está ocupado por otro servicio (como Caddy o Nginx), te alertará antes de aplicarlo.

---

## 📁 Estructura del Repositorio

```text
protocolos/
├── README.md                           # Documentación y guía de uso
├── install.sh                          # Script instalador universal
└── bhttp/
    ├── bin/
    │   ├── aarch64/BHTTP               # Binario compilado para ARM64
    │   └── x86_64/BHTTP                # Binario compilado para x86_64
    ├── runtime/
    │   └── aarch64/glibc235.tar.gz     # Micro-runtime GLIBC 2.35 para ARM64 (< 1 MB)
    ├── scripts/
    │   ├── bhttp_menu.sh               # Panel interactivo de consola ('bhttp')
    │   └── bhttp_runner.sh             # Wrapper ejecutor con detección de runtime
    └── service/
        └── bhttp.service               # Servicio systemd
```

---

## 🛠️ Comandos de Servicio Manuales

Si prefieres gestionar el servicio con `systemctl`:

- **Ver estado:** `sudo systemctl status bhttp`
- **Reiniciar:** `sudo systemctl restart bhttp`
- **Detener:** `sudo systemctl stop bhttp`
- **Ver logs:** `sudo journalctl -u bhttp -f`
- **Archivo de configuración:** `/etc/bhttp/bhttp.conf`
