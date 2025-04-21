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
        apt install -y build-essential libssl-dev libsodium-dev libev-dev libprotobuf-dev unbound
    elif [ -f /etc/alpine-release ]; then
        apk add --no-cache build-base libressl-dev libsodium-dev libev-dev unbound
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

# Konfiguriere Unbound
configure_unbound() {
    if [[ "$ENABLE_DNSCRYPT" == "true" && "$ENABLE_UNBOUND" == "true" ]]; then
        echo "Konfiguriere Unbound..."

        # Ändere die Unbound-Konfiguration, um dnscrypt-proxy als Forwarder zu nutzen
        local unbound_config="/etc/unbound/unbound.conf.d/dnscrypt.conf"

        echo "server:" > "$unbound_config"
        echo "  forward-zone:" >> "$unbound_config"
        echo "    name: \".\"" >> "$unbound_config"
        echo "    forward-addr: 127.0.0.1@5353" >> "$unbound_config"  # dnscrypt-proxy läuft auf Port 5353

        # Unbound neustarten, damit die Konfiguration aktiv wird
        systemctl restart unbound

        echo "Unbound erfolgreich konfiguriert."
    else
        echo "ENABLE_DNSCRYPT und/oder ENABLE_UNBOUND sind nicht auf true gesetzt. Unbound wird nicht konfiguriert."
    fi
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

# Installiere Unbound und konfiguriere es, um dnscrypt-proxy zu verwenden
configure_unbound

# Setze DNS-Server (der Unbound-Server, der auf Port 53 lauscht)
set_dns_server "127.0.0.1"

echo "Unbound und dnscrypt-proxy erfolgreich installiert und konfiguriert."
