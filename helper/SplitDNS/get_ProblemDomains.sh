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
  
  # Deutsche Banken & Finanzdienste
  "dkb.de"
  "comdirect.de"
  "ing.de"
  "n26.com"
  "sparkasse.de"
  "postbank.de"
  "paypal.de"
  
  # Deutsche Webseiten mit möglichen VPN-Problemen
  "ebay.de"
  "otto.de"
  "zalando.de"
  "rtlplus.de"
  "zdf.de"
  "ard.de"
  
  # Linux-Repositories
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
)

# Netzwerkschnittstelle & Gateway für Routing
INTERFACE="enp1s0"
GATEWAY="192.168.10.1"
TABLE="enp1s0only"
LOGFILE="/var/log/splitdns_routing.log"

# Log-Funktion
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOGFILE"
}

log "==== Starte Routing-Update ===="

# Prüfen, ob die Routing-Tabelle existiert, dann leeren
if ip rule list | grep -q "$TABLE"; then
  log "Flushing routing table $TABLE..."
  ip route flush table "$TABLE"
else
  log "Routing table $TABLE does not exist, creating it..."
  ip rule add from all lookup "$TABLE"
fi

# DNS-Abfragen & Routen setzen (inkl. Subdomains)
for SERVER in "${DOMAINS[@]}"; do
  log "Resolving $SERVER and subdomains..."
  
  # Nur IPv4-Adressen sammeln, Leerzeichen als Trenner sicherstellen
  IPS=($(dig +short A "$SERVER" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"))
  
  # Subdomains über NSLOOKUP holen (sofern möglich)
  SUBDOMAINS=($(dig +short NS "$SERVER" | sed 's/\.$//'))
  
  for SUB in "${SUBDOMAINS[@]}"; do
    log "Checking subdomain: $SUB"
    IPS+=($(dig +short A "$SUB" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"))
  done

  if [[ ${#IPS[@]} -eq 0 ]]; then
    log "⚠️  Keine IPv4-Adressen für $SERVER gefunden, überspringe..."
    continue
  fi

  for IP in "${IPS[@]}"; do
    if ip route show table "$TABLE" | grep -q "$IP"; then
      log "✅ Route für $IP existiert bereits, überspringe..."
    else
      log "➕ Hinzufügen der Route für $IP via $GATEWAY ($INTERFACE)"
      ip route add "$IP" via "$GATEWAY" dev "$INTERFACE" table "$TABLE"
    fi
  done
done

log "✅ Routing-Updates abgeschlossen."
