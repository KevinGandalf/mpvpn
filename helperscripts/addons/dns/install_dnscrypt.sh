#!/bin/bash

# Überprüfe, ob das Skript als Root ausgeführt wird
if [[ $EUID -ne 0 ]]; then
    echo "Dieses Skript muss als Root ausgeführt werden." 
    exit 1
fi

# Lade globale Variablen
source /opt/mpvpn/globals.sh

# Installiere Abhängigkeiten
install_dependencies() {
    echo "Installiere notwendige Abhängigkeiten..."
    if [ -f /etc/debian_version ] || [ -f /etc/raspbian-release ]; then
        apt update
        apt install -y build-essential libssl-dev libsodium-dev libev-dev libprotobuf-dev
    elif [ -f /etc/alpine-release ]; then
        apk add --no-cache build-base libressl-dev libsodium-dev libev-dev
    else
        echo "Unbekannte Distribution. Abbruch."
        exit 1
    fi
}

# Installiere dnscrypt-proxy
install_dnscrypt_proxy() {
    echo "Installiere dnscrypt-proxy..."

    # Stelle sicher, dass das Verzeichnis existiert
    mkdir -p /opt/dnscrypt

    # Wechsle in das Verzeichnis
    cd /opt/dnscrypt

    # Holen der neuesten Version von dnscrypt-proxy
    git clone --branch release https://github.com/DNSCrypt/dnscrypt-proxy.git

    # Baue dnscrypt-proxy
    cd dnscrypt-proxy
    make

    # Installiere
    make install

    # Starte den dnscrypt-proxy
    systemctl enable dnscrypt-proxy
    systemctl start dnscrypt-proxy

    echo "dnscrypt-proxy erfolgreich installiert und gestartet."
}

# Konfiguriere dnscrypt-proxy
configure_dnscrypt_proxy() {
    echo "Konfiguriere dnscrypt-proxy..."

    # Konfiguriere dnscrypt-proxy für die Verbindung zu den gewünschten Servern
    local config_file="/opt/dnscrypt/dnscrypt-proxy/dnscrypt-proxy.toml"
    
    echo "server_names = [\"${DNSCRYPT_SERVER_NAMES[@]}\"]" > "$config_file"
    echo "require_dnssec = $DNSCRYPT_REQUIRE_DNSSEC" >> "$config_file"
    echo "require_nolog = $DNSCRYPT_REQUIRE_NOLOG" >> "$config_file"
    echo "require_nofilter = $DNSCRYPT_REQUIRE_NOFILTER" >> "$config_file"

    # Starte dnscrypt-proxy neu, um die Konfiguration zu übernehmen
    systemctl restart dnscrypt-proxy
}

# Setze DNS-Server für das System
set_dns_server() {
    local dns_server=$1
    echo "Setze DNS-Server auf $dns_server..."

    if systemctl is-active --quiet systemd-resolved; then
        nmcli con mod "Wired connection 1" ipv4.dns "$dns_server"
        systemctl restart systemd-resolved
    elif [ -f /etc/resolv.conf ]; then
        echo "nameserver $dns_server" > /etc/resolv.conf
    fi
}

# Installiere Abhängigkeiten
install_dependencies

# Installiere dnscrypt-proxy
install_dnscrypt_proxy

# Konfiguriere dnscrypt-proxy
configure_dnscrypt_proxy

# Setze DNS-Server
for server in "${DNSCRYPT_SERVER_NAMES[@]}"; do
    set_dns_server "$server"
done

echo "dnscrypt-proxy erfolgreich installiert und konfiguriert."
