#!/bin/bash

# Definiere die Datei, in der die IP-Adressen gespeichert werden
IP_FILE="/opt/mpvpn/helperscripts/splitdns/vpn_bypass_ips.txt"
IP_FILE_PREVIOUS="/opt/mpvpn/helperscripts/splitdns/vpn_bypass_ips_previous.txt"

# Definiere das Gateway für enp1s0
#Ggf. Anpassen!!!
GATEWAY_enp1s0="192.168.1.1"
INTERFACE="enp1s0"
ROUTING_TABLE="enp1s0only"

# 1. Lade die IP-Adressen von GitHub herunter
echo "$(date) - Lade IP-Adressen von GitHub herunter..."
curl -s https://lou.h0rst.us/vpn_bypass.txt -o "$IP_FILE"

# 2. Lade die IP-Adressen in ein Array
mapfile -t ip_list < "$IP_FILE"

# 3. Berechnung für Fortschrittsbalken
TOTAL_IPS=${#ip_list[@]}
START_TIME=$(date +%s)

progress_bar() {
  local current=$1
  local elapsed_time=$(( $(date +%s) - START_TIME ))

  # Verhindern von Division durch 0 (bei den ersten paar IPs)
  if [[ $current -gt 0 ]]; then
    local avg_time_per_ip=$(echo "scale=2; $elapsed_time / $current" | bc)
  else
    local avg_time_per_ip=0
  fi

  local remaining_ips=$(( TOTAL_IPS - current ))
  local estimated_remaining_time=$(echo "scale=0; $avg_time_per_ip * $remaining_ips / 1" | bc)

  local width=50
  local progress=$(( (current * width) / TOTAL_IPS ))
  local remaining=$(( width - progress ))

  printf "\r["
  for ((i=0; i<progress; i++)); do printf "#"; done
  for ((i=0; i<remaining; i++)); do printf "-"; done
  printf "] %d%% | ⏳ Restzeit: %ds" $(( (current * 100) / TOTAL_IPS )) "$estimated_remaining_time"
}

# 4. Füge neue Routen hinzu oder aktualisiere sie
for i in "${!ip_list[@]}"; do
    ip_only=$(echo "${ip_list[$i]}" | cut -d'/' -f1)

    # Überprüfen, ob die IP-Adresse bereits als Route existiert
    if ! ip route show | grep -q "$ip_only"; then
        echo "$(date) - Neue IP-Adresse $ip_only gefunden, füge Route hinzu" >> /var/log/vpn_routing.log
        sudo ip route add "$ip_only" via "$GATEWAY_enp1s0" dev "$INTERFACE" 
    fi

    # Fortschrittsbalken aktualisieren
    progress_bar "$((i+1))"
done

# 5. Speichere die aktuelle Liste als die vorherige Liste für den nächsten Vergleich
echo -e "\n$(date) - Speichere die aktuelle IP-Liste für den nächsten Vergleich..."
cp "$IP_FILE" "$IP_FILE_PREVIOUS"

echo "$(date) - ✅ Abgleich abgeschlossen."
