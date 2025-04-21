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

# Installiere DNSCrypt
echo "Installiere DNSCrypt..."
if [ -f /etc/almalinux-release ]; then
    dnf install -y epel-release
    dnf install -y dnscrypt-proxy
elif [ -f /etc/rocky-release ]; then
    dnf install -y epel-release
    dnf install -y dnscrypt-proxy
elif [ -f /etc/centos-release ]; then
    dnf install -y epel-release
    dnf install -y dnscrypt-proxy
elif [ -f /etc/redhat-release ]; then
    dnf install -y epel-release
    dnf install -y dnscrypt-proxy
elif [ -f /etc/debian_version ] || [ -f /etc/raspbian-release ]; then
    apt update
    apt install -y dnscrypt-proxy
else
    echo "Unbekannte Distribution. Abbruch."
    exit 1
fi

# Konfiguration des DNSCrypt-Servers
dnscrypt_config="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
echo "server_names = [\"${DNSCRYPT_SERVER_NAMES[@]}\"]" > "$dnscrypt_config"
echo "require_dnssec = $DNSCRYPT_REQUIRE_DNSSEC" >> "$dnscrypt_config"
echo "require_nolog = $DNSCRYPT_REQUIRE_NOLOG" >> "$dnscrypt_config"
echo "require_nofilter = $DNSCRYPT_REQUIRE_NOFILTER" >> "$dnscrypt_config"

# DNS-Server nach DNSCrypt-Konfiguration setzen
for server in "${DNSCRYPT_SERVER_NAMES[@]}"; do
    set_dns_server "$server"
done

echo "DNSCrypt erfolgreich installiert und konfiguriert."
