#!/bin/bash

# GitHub URL zur Whitelist
WHITELIST_URL="https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt"
WHITELIST_FILE="/tmp/whitelist.txt"

# Whitelist von GitHub herunterladen
curl -s "$WHITELIST_URL" -o "$WHITELIST_FILE"

if [ ! -f "$WHITELIST_FILE" ]; then
  echo "Fehler beim Herunterladen der Whitelist-Datei!"
  exit 1
fi

# Liste von DNS-Servern
dns_servers=(
  "8.8.8.8"   # Google
  "8.8.4.4"   # Google
  "1.1.1.1"   # Cloudflare
  "1.0.0.1"   # Cloudflare
  "208.67.222.222"  # OpenDNS
  "208.67.220.220"  # OpenDNS
  "195.230.180.3"   # Beispiel ISP DNS
  "217.146.178.5"    # Beispiel ISP DNS
)

# Zufällige Auswahl der DNS-Server
random_dns=$(shuf -e "${dns_servers[@]}" -n 1)

# Zufällige Domains aus der Whitelist auswählen (maximal 5 Domains)
random_domains=()
while IFS= read -r line; do
  [[ "$line" =~ ^# || -z "$line" ]] && continue
  random_domains+=("$line")
done < "$WHITELIST_FILE"

# Zufällige Auswahl von 5 Domains
selected_domains=$(shuf -e "${random_domains[@]}" -n 5)

# Dummy-Traffic erzeugen
for domain in $selected_domains; do
  traffic_type=$((RANDOM % 3)) # Zufällig zwischen DNS, HTTP/HTTPS und UDP wählen
  case $traffic_type in
    0)
      echo "Generiere DNS-Traffic für $domain über DNS-Server $random_dns"
      dig @$random_dns "$domain" > /dev/null 2>&1
      ;;
    1)
      echo "Generiere HTTP/HTTPS-Traffic für $domain"
      curl -s "https://$domain" > /dev/null 2>&1
      ;;
    2)
      echo "Generiere UDP-Traffic für $domain"
      nc -uzw3 "$domain" 53 > /dev/null 2>&1
      ;;
    *)
      echo "Ungültiger Verkehrstyp."
      ;;
  esac
  sleep $((RANDOM % 5 + 1)) # Pause zwischen den Anfragen
done
