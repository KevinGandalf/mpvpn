#!/bin/bash

set -e

GLOBAL_CONF="$BASE_PATH/globals.conf"
TEMPFILE="/tmp/xray_server_setup.tmp"

# OS-Erkennung
get_os_type() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Prüfen ob tun2socks/xray installiert sind
install_dependencies() {
    OS=$(get_os_type)
    case "$OS" in
        debian|ubuntu|raspbian)
            apt update
            apt install -y curl unzip xray tun2socks
            ;;
        alpine)
            apk update
            apk add curl unzip xray tun2socks
            ;;
        rhel|rocky|almalinux)
            dnf install -y epel-release
            dnf install -y curl unzip xray tun2socks
            ;;
        *)
            echo "Nicht unterstütztes OS: $OS"
            exit 1
            ;;
    esac
}

# Lade Konfigurationsvariablen
load_globals() {
    if [ -f "$GLOBAL_CONF" ]; then
        source "$GLOBAL_CONF"
    else
        echo "Fehlende globals.conf"
        exit 1
    fi
}

# Schreibe/ersetze Variable in globals.conf
set_config_var() {
    local key="$1"
    local value="$2"
    if grep -q "^$key=" "$GLOBAL_CONF"; then
        sed -i "s|^$key=.*|$key=\"$value\"|" "$GLOBAL_CONF"
    else
        echo "$key=\"$value\"" >> "$GLOBAL_CONF"
    fi
}

# Generiere zufälliges Passwort
generate_password() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
}

# Generiere freien zufälligen Port
generate_random_port() {
    while :; do
        PORT=$(( ( RANDOM % 20000 )  + 20000 ))
        ss -lnt | awk '{print $4}' | grep -q ":$PORT" || break
    done
    echo "$PORT"
}

# Interaktive Abfrage
get_user_input() {
    read -rp "Domainname des Xray-Servers: " XRAY_DOMAIN
    read -rp "Xray-HTTPS-Port [443]: " XRAY_PORT
    XRAY_PORT="${XRAY_PORT:-443}"
    XRAY_PATH="/"

    set_config_var "XRAY_DOMAIN" "$XRAY_DOMAIN"
    set_config_var "XRAY_PORT" "$XRAY_PORT"
    set_config_var "XRAY_PATH" "$XRAY_PATH"
}

# Bearbeite alle VPN-Verbindungen
prepare_vpn_configs() {
    local ALL_VPN_LIST=()
    
    if [ "$ENABLE_OVPN" = "true" ] && [ -n "${OVPN_LIST[*]}" ]; then
        ALL_VPN_LIST+=("${OVPN_LIST[@]}")
    fi

    if [ -n "${WGVPN_LIST[*]}" ]; then
        ALL_VPN_LIST+=("${WGVPN_LIST[@]}")
    fi

    for vpn in "${ALL_VPN_LIST[@]}"; do
        local PORT_VAR="XRAY_${vpn}_PORT"
        local PASS_VAR="XRAY_${vpn}_PASS"
        
        local PORT=$(generate_random_port)
        local PASS=$(generate_password)

        set_config_var "$PORT_VAR" "$PORT"
        set_config_var "$PASS_VAR" "$PASS"
        
        echo "$PORT_VAR=$PORT" >> "$TEMPFILE"
        echo "$PASS_VAR=$PASS" >> "$TEMPFILE"
    done
}

# Kopiere und führe Server-Setup aus
deploy_server_script() {
    echo "Domain=$XRAY_DOMAIN" >> "$TEMPFILE"
    echo "Port=$XRAY_PORT" >> "$TEMPFILE"
    echo "Path=$XRAY_PATH" >> "$TEMPFILE"

    read -rp "Zielserver (user@ip): " REMOTE_HOST

    scp "$TEMPFILE" "$REMOTE_HOST:/tmp/xray_server_setup.tmp"

    ssh "$REMOTE_HOST" 'bash -s' < /opt/mpvpn/xray_server_setup.sh

    # === Remote-Setup starten ===
echo ""
echo "===> Remote-Installation vorbereiten"

read -rp "Gib die IP oder den Hostnamen des Zielservers (Remote VPS) ein: " REMOTE_HOST
read -rp "Gib den SSH-Benutzernamen auf dem Zielserver ein (default: root): " SSH_USER
SSH_USER=${SSH_USER:-root}

echo "===> Übertrage Setup-Dateien an $SSH_USER@$REMOTE_HOST"
scp /opt/mpvpn/helperscripts/addons/xray/xray_server_setup.sh "$SSH_USER@$REMOTE_HOST:/tmp/xray_server_setup.sh"
scp /tmp/xray_server_setup.tmp "$SSH_USER@$REMOTE_HOST:/tmp/xray_server_setup.tmp"

echo "===> Führe Server-Setup auf dem Zielserver aus..."
ssh "$SSH_USER@$REMOTE_HOST" "chmod +x /tmp/xray_server_setup.sh && sudo bash /tmp/xray_server_setup.sh"
echo ""
echo "===> Server-Setup abgeschlossen. Starte nun die lokalen Xray-Clients..."
}

start_xray_client() {
# === Lese Liste der VPN-Konfigurationen aus globals.conf ===
source $BASE_PATH/globals.conf

# Starte systemd-Dienste für Xray pro Verbindung
for VPN in "${WGVPN_LIST[@]}"; do
    echo "Starte Xray-Dienst für $VPN..."
    systemctl enable xray-$VPN.service
    systemctl restart xray-$VPN.service
    # Starte tun2socks für jedes VPN
    echo "Starte tun2socks für $VPN..."
    tun2socks -proxy 127.0.0.1:$XRAY_PORT -tun-device /dev/net/tun -tun-name tun-$VPN &
    echo "tun2socks für $VPN gestartet."

    # Ausgabe der nötigen VPN-Konfigurationsänderungen
    echo ""
    echo "==> Für $VPN (WireGuard oder OpenVPN) musst du folgende Änderungen vornehmen:"
    echo "1. Ändere die 'AllowedIPs' in der WireGuard-Konfiguration (z.B. wg0.conf):"
    echo "   - Füge den Xray-Server als Ziel für den gesamten Verkehr hinzu, z.B. 'AllowedIPs = 0.0.0.0/0, ::/0'."
    echo "2. Falls du OpenVPN verwendest, ändere die Route in der Konfiguration (z.B. client.ovpn):"
    echo "   - Füge hinzu: 'route 0.0.0.0 0.0.0.0 vpn_gateway'."
    echo "3. Ändere das Standard-Routing, um den Tunnelverkehr über Xray zu leiten:"
    echo "   - Beispiel: 'PostUp = ip route add default via 127.0.0.1:$XRAY_PORT'."
done

if [[ "$ENABLE_OVPN" == "true" ]]; then
    for VPN in "${OVPN_LIST[@]}"; do
        echo "Starte Xray-Dienst für $VPN..."
        systemctl enable xray-$VPN.service
        systemctl restart xray-$VPN.service
        # Starte tun2socks für jedes VPN
        echo "Starte tun2socks für $VPN..."
        tun2socks -proxy 127.0.0.1:$XRAY_PORT -tun-device /dev/net/tun -tun-name tun-$VPN &
        echo "tun2socks für $VPN gestartet."

        # Ausgabe der nötigen VPN-Konfigurationsänderungen
        echo ""
        echo "==> Für $VPN (WireGuard oder OpenVPN) musst du folgende Änderungen vornehmen:"
        echo "1. Ändere die 'AllowedIPs' in der WireGuard-Konfiguration (z.B. wg0.conf):"
        echo "   - Füge den Xray-Server als Ziel für den gesamten Verkehr hinzu, z.B. 'AllowedIPs = 0.0.0.0/0, ::/0'."
        echo "2. Falls du OpenVPN verwendest, ändere die Route in der Konfiguration (z.B. client.ovpn):"
        echo "   - Füge hinzu: 'route 0.0.0.0 0.0.0.0 vpn_gateway'."
        echo "3. Ändere das Standard-Routing, um den Tunnelverkehr über Xray zu leiten:"
        echo "   - Beispiel: 'PostUp = ip route add default via 127.0.0.1:$XRAY_PORT'."
    done
fi

echo "Alle Xray-Clients und tun2socks-Instanzen wurden erfolgreich gestartet."
}

# Funktion zur Installation von tun2socks (OS-spezifisch)
install_tun2socks() {
    local OS=$(uname -s)
    
    case $OS in
        Linux)
            if command -v apt-get &> /dev/null; then
                apt-get install -y tun2socks
            elif command -v yum &> /dev/null; then
                yum install -y tun2socks
            elif command -v pacman &> /dev/null; then
                pacman -S --noconfirm tun2socks
            fi
            ;;
        *)
            echo "Unsupported OS"
            exit 1
            ;;
    esac
}

# Hauptfunktion
main() {
    install_dependencies
    load_globals
    get_user_input
    > "$TEMPFILE"
    prepare_vpn_configs
    deploy_server_script
    start_xray_client
    install_tun2socks
    echo "Clientsetup abgeschlossen."
}

main
