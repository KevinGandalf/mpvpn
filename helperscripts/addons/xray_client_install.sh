#!/bin/bash

# Pfad zur globals.conf
GLOBAL_CONF="/opt/mpvpn/globals.conf"

# Überprüfe das Betriebssystem
OS=$(lsb_release -i | awk '{print $2}')

# Wenn die globals.conf nicht existiert, erstelle sie
if [ ! -f "$GLOBAL_CONF" ]; then
    echo "globals.conf nicht gefunden. Erstelle eine neue Konfiguration."
    touch "$GLOBAL_CONF"
fi

# UUID automatisch generieren, falls sie nicht in globals.conf vorhanden ist
XRAY_UUID=$(uuidgen)

# Lesen der bestehenden Werte
XRAY_DOMAIN=$(grep -i "XRAY_DOMAIN" "$GLOBAL_CONF" | cut -d '=' -f2 | tr -d ' ')
XRAY_PORT=$(grep -i "XRAY_PORT" "$GLOBAL_CONF" | cut -d '=' -f2 | tr -d ' ')
XRAY_PATH=$(grep -i "XRAY_PATH" "$GLOBAL_CONF" | cut -d '=' -f2 | tr -d ' ')

# Wenn keine Domain vorhanden ist, frage nach der Eingabe
if [ -z "$XRAY_DOMAIN" ]; then
    read -p "Bitte gib die Domain ein (z.B. example.com): " XRAY_DOMAIN
fi

# Wenn kein Port vorhanden ist, frage nach der Eingabe (Standardwert 443)
if [ -z "$XRAY_PORT" ]; then
    read -p "Bitte gib den Port ein (Standard: 443): " XRAY_PORT
    if [ -z "$XRAY_PORT" ]; then
        XRAY_PORT="443"
    fi
fi

# Wenn kein Path vorhanden ist, frage nach der Eingabe (Standardwert "/")
if [ -z "$XRAY_PATH" ]; then
    read -p "Bitte gib den Pfad ein (Standard: /): " XRAY_PATH
    if [ -z "$XRAY_PATH" ]; then
        XRAY_PATH="/"
    fi
fi

# Wenn keine UUID vorhanden, füge sie hinzu
if ! grep -q "XRAY_UUID" "$GLOBAL_CONF"; then
    echo "XRAY_UUID=$XRAY_UUID" >> "$GLOBAL_CONF"
else
    sed -i "s/^XRAY_UUID=.*/XRAY_UUID=$XRAY_UUID/" "$GLOBAL_CONF"
fi

# Aktualisiere die anderen Konfigurationswerte
if ! grep -q "XRAY_DOMAIN" "$GLOBAL_CONF"; then
    echo "XRAY_DOMAIN=$XRAY_DOMAIN" >> "$GLOBAL_CONF"
else
    sed -i "s/^XRAY_DOMAIN=.*/XRAY_DOMAIN=$XRAY_DOMAIN/" "$GLOBAL_CONF"
fi

if ! grep -q "XRAY_PORT" "$GLOBAL_CONF"; then
    echo "XRAY_PORT=$XRAY_PORT" >> "$GLOBAL_CONF"
else
    sed -i "s/^XRAY_PORT=.*/XRAY_PORT=$XRAY_PORT/" "$GLOBAL_CONF"
fi

if ! grep -q "XRAY_PATH" "$GLOBAL_CONF"; then
    echo "XRAY_PATH=$XRAY_PATH" >> "$GLOBAL_CONF"
else
    sed -i "s/^XRAY_PATH=.*/XRAY_PATH=$XRAY_PATH/" "$GLOBAL_CONF"
fi

# Installiere Xray für verschiedene Distributionen
echo "Installiere Xray..."

if [ "$OS" == "Ubuntu" ] || [ "$OS" == "Debian" ]; then
    sudo apt update
    sudo apt install -y curl unzip
    bash <(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
elif [ "$OS" == "RaspberryPi" ]; then
    sudo apt update
    sudo apt install -y curl unzip
    bash <(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
elif [ "$OS" == "AlmaLinux" ] || [ "$OS" == "Rocky" ] || [ "$OS" == "RHEL" ]; then
    sudo yum install -y curl unzip
    bash <(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
elif [ "$OS" == "Alpine" ]; then
    sudo apk add --no-cache curl unzip
    bash <(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
else
    echo "Nicht unterstütztes Betriebssystem."
    exit 1
fi

# Erstelle Xray-Client-Konfiguration
echo "Erstelle Xray-Client-Konfiguration..."

cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": 10808,
    "protocol": "socks",
    "settings": { "udp": true }
  }],
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "$XRAY_DOMAIN",
        "port": "$XRAY_PORT",
        "users": [{ "id": "$XRAY_UUID", "encryption": "none" }]
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "serverName": "$XRAY_DOMAIN",
        "allowInsecure": false
      },
      "wsSettings": { "path": "$XRAY_PATH" }
    }
  }]
}
EOF

# Xray starten
echo "Starte Xray..."
sudo systemctl enable xray
sudo systemctl start xray

echo "Client-Installation abgeschlossen!"
echo "UUID für Xray: $XRAY_UUID"
