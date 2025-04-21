#!/bin/bash

source /opt/mpvpn/globals.sh

LOG_FILE="$BASE_PATH/helperscripts/misc/logs/vpn_conncheck.log"
timestamp=$(date "+%Y-%m-%d %H:%M:%S")

# Verzeichnis erstellen, falls nicht vorhanden
LOG_DIR="$(dirname "$LOG_FILE")"
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

# Logfile erstellen, falls nicht vorhanden
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
fi

# Alle Interfaces zusammenführen
all_interfaces=("${WGVPN_LIST[@]}" "${OVPN_LIST[@]}")
wg_has_ip=0

# Loggen der IPs für alle Interfaces
for interface in "${all_interfaces[@]}"; do
  if ip link show "$interface" 2>/dev/null | grep -q "UP"; then
    ip=$(curl --interface "$interface" -s ipinfo.io | grep -oP '"ip": "\K[^"]+')

    if [[ -n $ip ]]; then
      echo "$timestamp - $interface: $ip" >> "$LOG_FILE"
      if [[ " ${WGVPN_LIST[*]} " =~ " ${interface} " ]]; then
        wg_has_ip=1
      fi
    else
      echo "$timestamp - $interface: Keine IP erhalten" >> "$LOG_FILE"
    fi
  fi
done

# Falls kein WireGuard eine IP hat → entferne Split-Routen über tun0/tun1
if [[ $wg_has_ip -eq 0 ]]; then
  echo "$timestamp - Kein WireGuard-VPN mit IP gefunden, überprüfe Routen..." >> "$LOG_FILE"

  # Routen prüfen & ggf. löschen
  declare -a routes=(
    "0.0.0.0/1 via 10.100.0.1 dev tun0"
    "128.0.0.0/1 via 10.100.0.1 dev tun0"
    "0.0.0.0/1 via 10.8.8.1 dev tun1"
    "128.0.0.0/1 via 10.8.8.1 dev tun1"
  )

  for route in "${routes[@]}"; do
    if ip route show | grep -q "$route"; then
      ip route del $route
      echo "$timestamp - Route entfernt: $route" >> "$LOG_FILE"
    fi
  done
fi

# Überprüfen, ob OpenVPN aktiviert ist
if [ "$ENABLE_OVPN" = true ]; then
    # OpenVPN-IPs loggen
    for vpn in "${OVPN_LIST[@]}"; do
        # Falls OpenVPN aktiv ist, IP abfragen und loggen
        if ip link show "$vpn" 2>/dev/null | grep -q "UP"; then
            ip=$(curl --interface "$vpn" -s ipinfo.io | grep -oP '"ip": "\K[^"]+')

            if [[ -n $ip ]]; then
                echo "$timestamp - $vpn: $ip" >> "$LOG_FILE"
            else
                echo "$timestamp - $vpn: Keine IP erhalten" >> "$LOG_FILE"
            fi
        fi
    done
else
    echo "$timestamp - OpenVPN ist deaktiviert – keine OpenVPN-IP-Protokolle werden erfasst." >> "$LOG_FILE"
fi
