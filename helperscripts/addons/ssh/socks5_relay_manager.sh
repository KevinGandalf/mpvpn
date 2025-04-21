#!/bin/bash
set -e

# Pfad zur globals.sh
GLOBALS_FILE="/opt/mpvpn/globals.sh"
SYSTEMD_DIR="/etc/systemd/system"

# Funktion zum Einlesen der Variablen aus globals.sh
load_globals() {
    if [[ -f "$GLOBALS_FILE" ]]; then
        source "$GLOBALS_FILE"
    else
        echo "❌ $GLOBALS_FILE nicht gefunden."
        exit 1
    fi
}

# Funktion zum Erstellen eines SSH-Schlüssels, falls keiner vorhanden ist
generate_ssh_key() {
    if [[ ! -f "$SSH_PRIVATE_KEY_PATH" ]]; then
        echo "🔑 Kein SSH-Schlüssel gefunden, erzeuge neuen SSH-Schlüssel..."
        mkdir -p /root/.ssh
        ssh-keygen -t rsa -b 4096 -f "$SSH_PRIVATE_KEY_PATH" -N ""
        echo "✅ SSH-Schlüssel erstellt: $SSH_PRIVATE_KEY_PATH"
    else
        echo "ℹ️ SSH-Schlüssel bereits vorhanden: $SSH_PRIVATE_KEY_PATH"
    fi
}

# Funktion zum Erstellen eines systemd-Services für jedes Relay
create_systemd_service() {
    local SSH_TARGET=$1
    local SSH_EXTERNAL_PORT=$2
    local SSH_LOCAL_PORT=$3
    local SERVICE_NAME="socks5_relay_$SSH_LOCAL_PORT.service"

    echo "🔧 Erstelle systemd Service für SOCKS5-Relay: $SSH_LOCAL_PORT"

    cat <<EOF > "$SYSTEMD_DIR/$SERVICE_NAME"
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

    echo "✅ Systemd-Service für SOCKS5-Relay $SSH_LOCAL_PORT erstellt und gestartet."
}

# Funktion zum Starten aller Relays
start_all_relays() {
    if [[ "$ENABLE_sSSH" != true ]]; then
        echo "ℹ️  SSH-SOCKS5-Relays sind in globals.sh deaktiviert (ENABLE_sSSH=false)."
        return
    fi

    for relay in "${SSH_RELAY_LIST[@]}"; do
        SSH_TARGET=$(echo "$relay" | awk '{print $1}')
        SSH_EXTERNAL_PORT=$(echo "$relay" | awk '{print $2}')
        SSH_LOCAL_PORT=$(echo "$relay" | awk '{print $3}')

        create_systemd_service "$SSH_TARGET" "$SSH_EXTERNAL_PORT" "$SSH_LOCAL_PORT"
    done
}

# SSH-Schlüssel erzeugen (falls erforderlich)
generate_ssh_key

# Relays starten
load_globals
start_all_relays
