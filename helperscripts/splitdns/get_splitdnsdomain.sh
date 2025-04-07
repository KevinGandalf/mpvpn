#!/bin/bash

# Problematische Domains mit VPN (erweiterbar, inkl. Wildcards für Subdomains)
DOMAINS=(
  "bild.de"
  "netflix.com"
  "amazon.de"
  "amazon.com"
  "paypal.com"
  "bankofamerica.com"
  "sparkasse.de"
  "postbank.de"
  "playstation.com"
  "nintendo.com"
  "steamcommunity.com"
  "epicgames.com"
  "icloud.com"
  "github.com"
  "kicker.de"
  "dkb.de"
  "comdirect.de"
  "ing.de"
  "n26.com"
  "ebay.de"
  "otto.de"
  "zalando.de"
  "rtlplus.de"
  "zdf.de"
  "ard.de"
  "repo.almalinux.org"
  "mirror.centos.org"
  "mirrors.edge.kernel.org"
  "vault.centos.org"
  "dl.fedoraproject.org"
  "mirrors.fedoraproject.org"
  "deb.debian.org"
  "security.debian.org"
  "ftp.debian.org"
  "archive.ubuntu.com"
  "security.ubuntu.com"
  "ppa.launchpad.net"
  "mirror.archlinuxarm.org"
  "archlinux.org"
  "mirrors.kernel.org"
  "repo.manjaro.org"
  "download.opensuse.org"
  "mirrorcache.opensuse.org"
  "distfiles.gentoo.org"
  "gentoo.osuosl.org"
  "packagecloud.io"
  "repo.nordvpn.com"
  "mirrors.almalinux.org"
  "mirror.virtarix.com"
  "mirror.junda.nl"
  "app.n26.de"
  "elrepo.org"
  "mirrors.elrepo.org"
  "mirror.selfnet.de"
  "kleinanzeigen.de"
)
# Netzwerkschnittstelle & Gateway für Routing
INTERFACE="enp1s0"
GATEWAY="192.168.1.1"
TABLE="100"
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
if ip rule list | grep -q "$TABLE"; then
echo "Flushing routing table $TABLE..."
ip route flush table $TABLE
else
echo "Routing table $TABLE does not exist, creating it..."
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

# NordVPN-IPs ermitteln um DNS Leaks zu vermeiden
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
      ip route add "$IP" via "$GATEWAY" dev "$INTERFACE" table "$TABLE"
      iptables -t mangle -A PREROUTING -d "$IP" -j MARK --set-mark "$TABLE"
      log "Route für $IP hinzugefügt"
    fi
  done

  ((CURRENT_COUNT++))
  progress_bar "$TOTAL_DOMAINS" "$CURRENT_COUNT" "$SERVER"
done

echo -e "\n✅ Routing-Update abgeschlossen."
log "✅ Routing-Update abgeschlossen."
