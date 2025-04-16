![MPVPN Logo](mpvpn_logo_klein.png)
[![Join our Discord](https://img.shields.io/discord/PK4jdyUd?label=Discord&logo=discord&style=for-the-badge)](https://discord.gg/qXRzXvzJQM)

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

## Installationsscript:
```bash
#Ubuntu / Debian
apt install -y wget && wget -O - -q https://kevingandalf.github.io/install-mvpn | bash

#Almalinux, RHEL, Rocky, CentOS etc.
dnf install -y wget && wget -O - -q https://kevingandalf.github.io/install-mvpn | bash
```


1. Ein paar dinge vorab erledigen und klonen des Repository:
    ```bash
    sudo apt update && sudo apt upgrade -y && sudo apt install -y sudo git curl wget
    cd /opt
    #Root Passwort festlegen
    sudo passwd
    su
    git clone https://github.com/KevinGandalf/mpvpn
    ```

2. Mache das Script ausführbar:
    ```bash
    cd /opt/mpvpn
    find /opt/mpvpn -type f -name "*.sh" -exec chmod +x {} \;
    ln -s /opt/mpvpn/helperscripts/assets/menu.sh /usr/local/bin/mpvpn
    mpvpn --install
    ```

3. Die Basis-Konfigurationen befinden sich in der Datei `globals.sh`. Die Konfiguration der zu verwendenden VPN-Verbindungen und Routing-Tabellen erfolgt hier.

4. Wireguard (und ggf. OpenVPN Verbindung) Verbindung per Drag&Drop hinzufügen(z.B. per Putty!):
    ```bash
    mpvpn --addwg
    #für OpenVPN
    mpvpn --addovpn
    ```

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
```    
5. MPVPN starten:
    ```bash
    mpvpn --startmpvpn
    ```

## mpvpn Befehle
```bash
    Verfügbare Optionen für mpvpn:
      --startmpvpn : Startet MPVPN
      --install    : Installiert die Abhängigkeiten
      --addwg      : Neue WireGuard-Verbindung hinzufügen.
      --addovpn    : Neue OpenVPN-Verbindung hinzufügen.
      --list       : Alle Verbindungen anzeigen.
      --help       : Zeigt diese Hilfe an.
      --version    : Gibt die Version des Skripts aus.
```

