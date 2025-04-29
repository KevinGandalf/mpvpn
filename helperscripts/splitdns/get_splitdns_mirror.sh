#!/bin/bash
source $BASE_PATH/globals.conf

# === Variablen ===
LOGFILE="/var/log/splitdns_routing_mirror.log"
STATUS_FILE="/opt/mpvpn/splitdns/statusdomain.txt"

# DNS-Server für die Auflösung
DNS_SERVERS=(
  "1.1.1.1"
  "8.8.8.8"
  "9.9.9.9"
  "208.67.222.222"
  "103.86.96.100"
  "103.86.99.100"
)

# === Log-Funktion ===
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $1" >> "$LOGFILE"
}

# === Fortschrittsbalken ===
progress_bar() {
  local total=$1
  local current=$2
  local width=50
  local progress=$(( (current * width) / total ))
  local remaining=$(( width - progress ))

  local elapsed_time=$SECONDS
  local avg_time_per_domain=$((elapsed_time / current))
  local remaining_time=$((avg_time_per_domain * (total - current)))
  local remaining_minutes=$((remaining_time / 60))
  local remaining_seconds=$((remaining_time % 60))

  printf "\r["
  for ((i=0; i<progress; i++)); do printf "#"; done
  for ((i=0; i<remaining; i++)); do printf "-"; done
  printf "] %d%% | ⏳ Restzeit: %02d:%02d | %s" $(( (current * 100) / total )) $remaining_minutes $remaining_seconds "$3"
}

# === Tabelle "mirror" ermitteln ===
for entry in "${EXTRA_RT_TABLES[@]}"; do
    rt_id=$(echo "$entry" | awk '{print $1}')
    rt_name=$(echo "$entry" | awk '{print $2}')
    if [[ "$rt_name" == "mirror" ]]; then
        MARK=$rt_id
        break
    fi
done

if [[ -z "$MARK" ]]; then
    echo  "Tabelle 'mirror' nicht gefunden!"
    exit 1
fi

# === Routingtabelle absichern ===
if ! grep -qE "^$MARK[[:space:]]+mirror" /etc/iproute2/rt_tables; then
    echo "$MARK mirror" >> /etc/iproute2/rt_tables
    log "Routing-Tabelle $MARK ('clear') in /etc/iproute2/rt_tables eingetragen."
fi

# === Tabelle leeren, falls vorhanden ===
if ip rule list | grep -q "$MARK"; then
    echo "Flushing routing table $MARK..."
    ip route flush table "$MARK"
else
    echo "Routing table $MARK wird neu erstellt..."
fi

# === Starte Update ===
log "==== Starte Routing-Update ===="
echo "Routing-Update läuft..."
TOTAL_DOMAINS=${#MIRRORDOMAINS[@]}
CURRENT_COUNT=0

declare -A NORDVPN_IPS
declare -A ADDED_IPS

# === NordVPN blockieren ===
for DNS in "${DNS_SERVERS[@]}"; do
  IPS=($(dig +short A "nordvpn.com" @"$DNS" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"))
  for IP in "${IPS[@]}"; do
    NORDVPN_IPS["$IP"]=1
  done
done
log "Gefundene NordVPN-IPs: ${!NORDVPN_IPS[@]}"

# === Domains durchgehen ===
for SERVER in "${MIRRORDOMAINS[@]}"; do
  log "Resolving $SERVER..."
  declare -A UNIQUE_IPS

  for DNS in "${DNS_SERVERS[@]}"; do
    IPS=($(dig +short A "$SERVER" @"$DNS" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"))
    for IP in "${IPS[@]}"; do
      [[ ${NORDVPN_IPS[$IP]} ]] && log "⚠️  $IP gehört zu NordVPN, ignoriert." && continue
      UNIQUE_IPS["$IP"]=1
    done
  done

  # === Routen setzen ===
  for IP in "${!UNIQUE_IPS[@]}"; do
    if ! ip route show table "$MARK" | grep -q "$IP"; then
      ip route add "$IP" via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$MARK" 2>/dev/null
      log "Route für $IP zur Tabelle $MARK hinzugefügt"
    fi

    if ! iptables -t mangle -C PREROUTING -d "$IP" -j MARK --set-mark "$MARK" 2>/dev/null; then
      iptables -t mangle -A PREROUTING -d "$IP" -j MARK --set-mark "$MARK"
      log "iptables-Regel für $IP gesetzt"
    fi

    ADDED_IPS["$IP"]=1
  done

  ((CURRENT_COUNT++))
  progress_bar "$TOTAL_DOMAINS" "$CURRENT_COUNT" "$SERVER"
done

# === Status-Datei schreiben ===
{
  echo "Letztes Routing-Update: $(date)"
  echo "Verwendete Routing-Tabelle: $MARK (clear)"
  echo "Standard-Gateway: $DEFAULT_WANGW"
  echo "Netzwerkschnittstelle: $DEFAULT_LANIF"
  echo ""
  echo "Geroutete Domains:"
  for domain in "${DOMAINS[@]}"; do
    echo "  - $domain"
  done
  echo ""
  echo "Anzahl eindeutiger IPs: ${#ADDED_IPS[@]}"
  echo ""
  echo "Geroutete IP-Adressen:"
  for ip in "${!ADDED_IPS[@]}"; do
    echo "  - $ip"
  done
} > "$STATUS_FILE"

echo -e "\n✅ Routing-Update abgeschlossen."
log "✅ Routing-Update abgeschlossen."
