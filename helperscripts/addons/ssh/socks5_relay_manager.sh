#!/bin/bash
set -e

# Funktion zum Laden der globals.sh
load_globals() {
    # Pfad zur globals.sh Datei
    GLOBALS_FILE="/opt/mpvpn/globals.sh"

    # Überprüfen, ob die Datei existiert
    if [[ ! -f "$GLOBALS_FILE" ]]; then
        echo "❌ globals.sh nicht gefunden! Stelle sicher, dass die Datei unter $GLOBALS_FILE existiert."
        exit 1
    fi

    # Quelle der globals.sh Datei
    source "$GLOBALS_FILE"
}

# Funktion zum Hinzufügen von iptables-Regeln für eingehenden Traffic
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

# Funktion zum Erstellen eines SSH-Relays mit systemd und iptables-Regeln
create_systemd_service() {
    local SSH_TARGET=$1
    local SSH_EXTERNAL_PORT=$2
    local SSH_LOCAL_PORT=$3
    local SERVICE_NAME="socks5_relay_$SSH_LOCAL_PORT.service"

    echo "🔧 Erstelle systemd Service für SOCKS5-Relay: $SSH_LOCAL_PORT"

    cat <<EOF > "/etc/systemd/system/$SERVICE_NAME"
[Unit]
Description=SSH SOCKS5-Relay für $SSH_TARGET
After=network.target

[Service]
ExecStart=/usr/bin/ssh $SSH_CMD_OPTIONS -D $SSH_LOCAL_PORT $SSH_TARGET -p $SSH_EXTERNAL_PORT
Restart=always
User=root
Environment=HOME=/root

[Install]
WantedBy=multi-user.target
EOF

    # Systemd neu laden und Service aktivieren
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"

    # iptables-Regeln für den lokalen Port hinzufügen
    add_iptables_rules "$SSH_LOCAL_PORT"

    echo "✅ Systemd-Service für SOCKS5-Relay $SSH_LOCAL_PORT erstellt und gestartet."
}

# Funktion zum Starten aller Relays
start_all_relays() {
    if [[ "$ENABLE_sSSH" != true ]]; then
        echo "ℹ️  SSH-SOCKS5-Relays sind in globals.sh deaktiviert (ENABLE_sSSH=false)."
        return
    fi

    # Durch die Relays iterieren und die Konfiguration aus globals.sh laden
    for i in "${!SSH_RELAY_TARGETS[@]}"; do
        SSH_TARGET="${SSH_RELAY_TARGETS[$i]}"
        SSH_EXTERNAL_PORT="${SSH_RELAY_EXTERNAL_PORTS[$i]}"
        SSH_LOCAL_PORT="${SSH_RELAY_LOCAL_PORTS[$i]}"

        create_systemd_service "$SSH_TARGET" "$SSH_EXTERNAL_PORT" "$SSH_LOCAL_PORT"
    done
}

# SSH-Schlüssel überprüfen (erstellen oder vom anderen Server herunterladen)
if [[ -z "$SSH_PRIVATE_KEY_PATH" ]]; then
    echo "❌ SSH_PRIVATE_KEY_PATH ist nicht gesetzt. Bitte definieren Sie den Pfad zu Ihrem SSH-Schlüssel in globals.sh."
    exit 1
fi

# Prüfen, ob der Schlüssel vorhanden ist oder einen neuen generieren
if [[ -f "$SSH_PRIVATE_KEY_PATH" ]]; then
    echo "ℹ️ Vorhandener SSH-Schlüssel erkannt: $SSH_PRIVATE_KEY_PATH"
else
    # Wenn ein Remote-Schlüssel angegeben ist, diesen übertragen
    if [[ -n "$SSH_REMOTE_KEY_PATH" ]]; then
        download_existing_ssh_key
    else
        generate_ssh_key
    fi
fi

# Relays starten
load_globals
create_systemd_service
start_all_relays
