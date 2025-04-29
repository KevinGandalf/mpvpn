#!/bin/bash

# Füge SSH SOCKS5-Tunnel-Konfiguration zu globals.sh hinzu
add_ssh_socks5_tunnel() {
    # Lade globals.sh
    source $BASE_PATH/globals.conf

    echo "Füge eine neue SSH SOCKS5-Verbindung hinzu..."

    # Eingabeaufforderung für das Ziel
    read -p "Gib das Ziel für den SSH-Tunnel (z.B. ziel1.example.com): " target
    # Eingabeaufforderung für den externen Port
    read -p "Gib den externen Port für den SSH-Tunnel (z.B. 1337): " external_port
    # Eingabeaufforderung für den lokalen Port
    read -p "Gib den lokalen Port für den SSH-Tunnel (z.B. 2225): " local_port

    # Füge den neuen Eintrag zu den Arrays in globals.sh hinzu
    echo "Aktualisiere globals.sh mit der neuen SSH SOCKS5-Verbindung..."

    # Stelle sicher, dass ENABLE_SSH auf true gesetzt ist
    sed -i '/ENABLE_SSH=false/c\ENABLE_SSH=true' "$BASE_PATH/globals.sh"

    # Füge das neue Ziel, den externen und den lokalen Port zum jeweiligen Array hinzu
    sed -i "/SSH_RELAY_LIST/ s/\(SSH_RELAY_LIST=(.*\))/\1\n    \"$target\",/" "$BASE_PATH/globals.sh"
    sed -i "/SSH_RELAY_EXTERNAL_PORTS/ s/\(SSH_RELAY_EXTERNAL_PORTS=(.*\))/\1\n    \"$external_port\",/" "$BASE_PATH/globals.sh"
    sed -i "/SSH_RELAY_LOCAL_PORTS/ s/\(SSH_RELAY_LOCAL_PORTS=(.*\))/\1\n    \"$local_port\",/" "$BASE_PATH/globals.sh"

    echo "globals.sh wurde erfolgreich aktualisiert!"
}

add_iptables_rules() {
    local SSH_LOCAL_PORT=$1

    echo "🔧 Hinzufügen von iptables-Regeln für Port $SSH_LOCAL_PORT"

    # Erlaube Verbindungen zu dem lokalen Port (Zulassen von eingehendem Traffic)
    iptables -A INPUT -p tcp --dport "$SSH_LOCAL_PORT" -j ACCEPT
    iptables -A INPUT -p udp --dport "$SSH_LOCAL_PORT" -j ACCEPT

    # Optional: Weitere Regeln für IP-Quellen (z.B. localhost oder bestimmte IPs)
    iptables -A INPUT -p tcp --dport "$SSH_LOCAL_PORT" -s 127.0.0.1 -j ACCEPT
    iptables -A INPUT -p udp --dport "$SSH_LOCAL_PORT" -s 127.0.0.1 -j ACCEPT

    # Optional: Verbindung aus dem öffentlichen Internet blockieren
    iptables -A INPUT -p tcp --dport "$SSH_LOCAL_PORT" -j DROP
    iptables -A INPUT -p udp --dport "$SSH_LOCAL_PORT" -j DROP

    echo "✅ iptables-Regeln für Port $SSH_LOCAL_PORT hinzugefügt."
}

# Funktion, um den SSH Tunnel zu starten
start_ssh_socks5_tunnel() {
    # Lade globals.sh
    source $BASE_PATH/globals.conf

    # Prüfe, ob SSH aktiviert ist
    if [ "$ENABLE_SSH" == "true" ]; then
        echo "Erstelle SSH SOCKS5 Tunnel..."

        # Schleife durch alle SSH-Relay-Ziele und starte SSH-Tunnel
        for i in "${!SSH_RELAY_LIST[@]}"; do
            target="${SSH_RELAY_LIST[$i]}"
            external_port="${SSH_RELAY_EXTERNAL_PORTS[$i]}"
            local_port="${SSH_RELAY_LOCAL_PORTS[$i]}"

            echo "Starte SSH Tunnel für Ziel: $target, Externer Port: $external_port, Lokaler Port: $local_port"

            # SSH-Tunnel mit SOCKS5-Proxy erstellen
            ssh $SSH_CMD_OPTIONS -i "$SSH_PRIVATE_KEY_PATH" -D "$local_port" "$target" &
        done

        echo "SSH SOCKS5 Tunnel wurde erstellt."
    else
        echo "SSH ist nicht aktiviert. Bitte die Konfiguration überprüfen."
    fi
}

# Funktion für die Konfiguration des SSH SOCKS5-Tunnels
configure_ssh_socks5() {
    add_ssh_socks5_tunnel
    start_ssh_socks5_tunnel
    add_iptables_rules
}

# Aufruf der Funktion zur Konfiguration
configure_ssh_socks5
