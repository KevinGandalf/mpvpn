#!/bin/bash
source /opt/mpvpn/globals.sh

# Netzwerkschnittstelle & Gateway für Routing

# Finde die MARK für die Tabelle mit Name "clear"
for entry in "${EXTRA_RT_TABLES[@]}"; do
    rt_id=$(echo "$entry" | awk '{print $1}')
    rt_name=$(echo "$entry" | awk '{print $2}')

    if [[ "$rt_name" == "clear" ]]; then
        MARK=$rt_id
        break
    fi
done

# Wenn keine passende Tabelle gefunden wurde
if [[ -z "$MARK" ]]; then
    echo "❌ Tabelle 'clear' nicht in EXTRA_RT_TABLES gefunden!"
    exit 1
fi

LOGFILE="/var/log/splitdns_routing.log"

# DNS-Server für die Auflösung
DNS_SERVERS=(
  "1.1.1.1"  # Cloudflare
  "8.8.8.8"  # Google DNS
  "9.9.9.9"  # Quad9
  "208.67.222.222"  # OpenDNS
  "103.86.96.100"
  "103.86.99.100"
)

# Prüfen, ob die Routing-Tabelle existiert, dann leeren
if ip rule list | grep -q "$MARK"; then
echo "Flushing routing table $MARK..."
ip route flush table $MARK
else
echo "Routing table $MARK does not exist, creating it..."
fi

# Log-Funktion (nur ins Logfile schreiben)
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $1" >> "$LOGFILE"
}

# Fortschrittsbalken anzeigen mit Restzeit und aktueller Domain
progress_bar() {
  local total=$1
  local current=$2
  local width=50
  local progress=$(( (current * width) / total ))
  local remaining=$(( width - progress ))

  # Berechnung der verbleibenden Zeit
  local elapsed_time=$SECONDS
  local avg_time_per_domain=$((elapsed_time / current))
  local remaining_time=$((avg_time_per_domain * (total - current)))
  local remaining_minutes=$((remaining_time / 60))
  local remaining_seconds=$((remaining_time % 60))

  printf "\r["
  for ((i=0; i<progress; i++)); do printf "#"; done
  for ((i=0; i<remaining; i++)); do printf "-"; done
#  printf "] %d%% | ⏳ Restzeit: %02d:%02d" $(( (current * 100) / total )) $remaining_minutes $remaining_seconds "$3"
  printf "] %d%% | ⏳ Restzeit: %02d:%02d | %s" $(( (current * 100) / total )) $remaining_minutes $remaining_seconds "$3"

}

log "==== Starte Routing-Update ===="
echo "Routing-Update läuft..."

# Anzahl der Domains für den Fortschritt
TOTAL_DOMAINS=${#DOMAINS[@]}
CURRENT_COUNT=0

# NordVPN-IPs ermitteln
declare -A NORDVPN_IPS
for DNS in "${DNS_SERVERS[@]}"; do
  IPS=($(dig +short A "nordvpn.com" @${DNS} | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"))
  for IP in "${IPS[@]}"; do
    NORDVPN_IPS["$IP"]=1
  done
done
log "Gefundene NordVPN-IPs: ${!NORDVPN_IPS[@]}"

# DNS-Abfragen & Routen setzen
for SERVER in "${DOMAINS[@]}"; do
  log "Resolving $SERVER..."
  declare -A UNIQUE_IPS

  # Die Domain selbst auflösen
  for DNS in "${DNS_SERVERS[@]}"; do
    IPS=($(dig +short A "$SERVER" @${DNS} | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"))
    for IP in "${IPS[@]}"; do
      if [[ -n "${NORDVPN_IPS[$IP]}" ]]; then
        log "⚠️  IP $IP gehört zu NordVPN und wird ignoriert!"
        continue
      fi
      UNIQUE_IPS["$IP"]=1
    done
  done

  # Wildcards für Subdomains auflösen
  WILDCARD_DOMAIN="*.$SERVER"
  for DNS in "${DNS_SERVERS[@]}"; do
    IPS=($(dig +short A "$WILDCARD_DOMAIN" @${DNS} | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"))
    for IP in "${IPS[@]}"; do
      if [[ -n "${NORDVPN_IPS[$IP]}" ]]; then
        log "⚠️  IP $IP gehört zu NordVPN und wird ignoriert!"
        continue
      fi
      UNIQUE_IPS["$IP"]=1
    done
  done

  # Routen hinzufügen
  for IP in "${!UNIQUE_IPS[@]}"; do
    if ! ip route show | grep -q "$IP"; then
      ip route add "$IP" via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$MARK"
      iptables -t mangle -A PREROUTING -d "$IP" -j MARK --set-mark "$MARK"
      log "Route für $IP hinzugefügt"
    fi
  done

  ((CURRENT_COUNT++))
  progress_bar "$TOTAL_DOMAINS" "$CURRENT_COUNT" "$SERVER"
done

echo -e "\n✅ Routing-Update abgeschlossen."
log "✅ Routing-Update abgeschlossen."
