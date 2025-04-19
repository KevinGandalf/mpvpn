#!/bin/bash

WG_INTERFACE="wg0"
REAL_ENDPOINT="123.123.123.123"
OBFS4_PROXY_IP="99.99.99.99"
OBFS4_PROXY_DOMAIN="proxy.blubb.io"
HOSTS_FILE="/etc/hosts"

echo "[*] Stealth-Modus aktiv: Leite $REAL_ENDPOINT temporär über $OBFS4_PROXY_IP"

# Backup hosts
cp $HOSTS_FILE "${HOSTS_FILE}.bak"

# Eintrag in /etc/hosts setzen
echo "$OBFS4_PROXY_IP $REAL_ENDPOINT" >> $HOSTS_FILE

# Starte WireGuard
echo "[*] Starte WireGuard Interface $WG_INTERFACE ..."
wg-quick up $WG_INTERFACE

# Warten auf Handshake
echo "[*] Warte auf ersten Handshake ..."
while true; do
  HANDSHAKE=$(wg show $WG_INTERFACE latest-handshakes | awk '{print $2}')
  if [[ "$HANDSHAKE" -gt 0 ]]; then
    echo "[+] Handshake erfolgreich! Entferne hosts-Eintrag."
    break
  fi
  sleep 0.5
done

# Restore hosts
mv "${HOSTS_FILE}.bak" $HOSTS_FILE

echo "[*] Stealth-Phase beendet. VPN läuft nun direkt über $REAL_ENDPOINT."
