#!/bin/bash

# Überprüfe, ob das Skript als Root ausgeführt wird
if [[ $EUID -ne 0 ]]; then
    echo "Dieses Skript muss als Root ausgeführt werden." 
    exit 1
fi

# Lade globale Variablen
source /opt/mpvpn/globals.sh

# Funktion zum Setzen des DNS-Servers
set_dns_server() {
    local dns_server=$1
    # Überprüfen, ob systemd-resolved aktiv ist
    if systemctl is-active --quiet systemd-resolved; then
        echo "Setze DNS-Server mit systemd-resolved..."
        nmcli con mod "Wired connection 1" ipv4.dns "$dns_server"
        systemctl restart systemd-resolved
    elif [ -f /etc/resolv.conf ]; then
        # Ändern von /etc/resolv.conf (für Distributionen ohne systemd-resolved)
        echo "Setze DNS-Server in /etc/resolv.conf..."
        echo "nameserver $dns_server" > /etc/resolv.conf
    else
        echo "Fehler: Kein gültiges DNS-Konfigurationsziel gefunden."
        exit 1
    fi
    echo "DNS-Server auf $dns_server gesetzt."
}

# Installiere Unbound
echo "Installiere Unbound..."
if [ -f /etc/almalinux-release ]; then
    dnf install -y unbound
elif [ -f /etc/rocky-release ]; then
    dnf install -y unbound
elif [ -f /etc/centos-release ]; then
    dnf install -y unbound
elif [ -f /etc/redhat-release ]; then
    dnf install -y unbound
elif [ -f /etc/debian_version ] || [ -f /etc/raspbian-release ]; then
    apt update
    apt install -y unbound
else
    echo "Unbekannte Distribution. Abbruch."
    exit 1
fi

# Konfiguration von Unbound
unbound_config="/etc/unbound/unbound.conf.d/forward.conf"
echo "forward-zone:" > "$unbound_config"
echo "  name: \".\"" >> "$unbound_config"
for ip in "${SET_UNBOUND_DNS[@]}"; do
    echo "  forward-addr: $ip" >> "$unbound_config"
done

# DNS-Server nach Unbound-Konfiguration setzen
for server in "${SET_UNBOUND_DNS[@]}"; do
    set_dns_server "$server"
done

echo "Unbound erfolgreich installiert und konfiguriert."
