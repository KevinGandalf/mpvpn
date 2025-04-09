# mpvpn

**mpvpn** ist ein Script zur Verwaltung von Multipath-VPN-Verbindungen (WireGuard und OpenVPN). Es erlaubt das einfache Starten und Verwalten von VPN-Verbindungen sowie die Konfiguration von Routing-Tabellen.

Dafür muss das Script mpvpn.sh ausgeführt werden.

## Anforderungen

Alle Variablen werden in der `globals.sh` definiert. Die Anforderungen sind in der `requirements.sh` definiert – dieses Script muss einmalig ausgeführt werden.

Es installiert folgende Pakete:
- curl
- wget
- net-tools
- wireguard
- Bei Bedarf auch OpenVPN

Alle relevanten Start-Skripte befinden sich im Verzeichnis `/opt/mpvpn/helperscripts/startup`.

## Installation

1. Klone das Repository:
    ```bash
    cd /opt
    git clone https://github.com/KevinGandalf/mpvpn
    ```

2. Mache das Script ausführbar:
    ```bash
    chmod +x sh
    ./requirements.sh
    ```

3. Die Basis-Konfigurationen befinden sich in der Datei `globals.sh`. Die Konfiguration der zu verwendenden VPN-Verbindungen und Routing-Tabellen erfolgt hier.

## Konfiguration

Der Übersicht halber wurde das Main Script `mpvpn.sh` aufgeräumt und die Sequenzen in einzelne Scripte verpackt. Es gibt mehrere Variablen, die angepasst werden müssen:

### Folgende Variablen müssen ggf. angepasst werden:

```bash
# Basisverzeichnis für VPN-Skripte
BASE_PATH="/opt/mpvpn"

# Standard LAN Interface
DEFAULT_LANIF="enp1s0"

# Standard Gateway
DEFAULT_WANGW="192.168.1.1"

# WireGuard Konfigurationsverzeichnis
WG_CONF_DIR="/etc/wireguard"
# OpenVPN Konfigurationsverzeichnis
OVPN_CONF_DIR="/etc/openvpn"

# WireGuard Konfigurationsnamen (entsprechen den .conf-Dateien in /etc/wireguard)
WGVPN_LIST=("vpn1" "vpn2" "vpn3" "vpn4")

# Beispiel:
# WGVPN_LIST=("mullvad" "ovpn" "azirevpn" "surfshark")

# OpenVPN Konfigurationen
ENABLE_OVPN=false
# Default: ENABLE_OVPN=false
OVPN_LIST=("vpn5" "vpn6")
