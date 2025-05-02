#!/bin/bash
source $BASE_PATH/globals.conf

# Finde den Tabellennamen und die ID für SMTP
for entry in "${EXTRA_RT_TABLES[@]}"; do
  id=$(echo "$entry" | awk '{print $1}')
  name=$(echo "$entry" | awk '{print $2}')
  if [[ "$name" == "smtp" ]]; then
    MARK="$id"
    TABLE="$name"
    break
  fi
done

# Sanity Check
if [[ -z "$MARK" || -z "$TABLE" ]]; then
  echo "❌ SMTP Routing-Tabelle nicht in EXTRA_RT_TABLES gefunden!"
  exit 1
fi

# Netzwerkschnittstelle und Gateway aus globals
INTERFACE="${DEFAULT_LANIF}"
GATEWAY="${DEFAULT_WANGW}"

echo "⚙️  Verwende Table '$TABLE' mit Mark '$MARK' über Interface '$INTERFACE' via '$GATEWAY'"

### 1. Bereinigung bestehender Regeln ###
echo "🧹 Bereinige bestehende Regeln..."
ip route flush table "$TABLE" 2>/dev/null
iptables -t mangle -D PREROUTING -m set --match-set smtp_dst_ip dst -j MARK --set-mark "$MARK" 2>/dev/null
iptables -t mangle -D OUTPUT -m set --match-set smtp_dst_ip dst -j MARK --set-mark "$MARK" 2>/dev/null
ip rule del fwmark "$MARK" 2>/dev/null

### 2. ipset erstellen ###
echo "🆕 Erstelle ipset für SMTP-Server..."
ipset create smtp_dst_ip hash:net timeout 0 2>/dev/null || ipset flush smtp_dst_ip

### 3. Mailserver-Routing ###
for SERVER in "${MAIL_SERVERS[@]}"; do
  echo "🔍 Resolving $SERVER..."
  IPS=$(dig +short A "$SERVER" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
  
  if [[ -z "$IPS" ]]; then
    echo "⚠️  Keine IPs gefunden für $SERVER – übersprungen"
    continue
  fi

  for IP in $IPS; do
    echo "➕ Füge $IP zu ipset hinzu"
    ipset add smtp_dst_ip "$IP"
    
    # Explizite Route nur in der SMTP-Tabelle
    echo "🛣️  Route für $IP via $GATEWAY ($INTERFACE) in Table $TABLE"
    ip route add "$IP" via "$GATEWAY" dev "$INTERFACE" table "$TABLE" 2>/dev/null
    
    # Blockiere diese IPs in der Haupt-Routing-Tabelle für VPNs
    for VPN in mullvad1 mullvad2 azirevpn1 azirevpn2 ivpn1 ivpn2 pia nordvpn surfshark; do
      ip route del "$IP" dev "$VPN" 2>/dev/null
    done
  done
done

### 4. Routing-Regeln ###
echo "📌 Setze Routing-Regeln..."
ip rule add fwmark "$MARK" table "$TABLE" 2>/dev/null
ip route add default via "$GATEWAY" dev "$INTERFACE" table "$TABLE"

### 5. iptables-Regeln ###
echo "🔧 Konfiguriere iptables..."
# Markierung für ein- und ausgehenden Traffic
iptables -t mangle -A PREROUTING -m set --match-set smtp_dst_ip dst -j MARK --set-mark "$MARK"
iptables -t mangle -A OUTPUT -m set --match-set smtp_dst_ip dst -j MARK --set-mark "$MARK"

### 6. Port-basierte Regeln ###
echo "🔐 Setze port-basierte Regeln..."
ip rule add ipproto tcp dport 25 table "$TABLE" 2>/dev/null || true
ip rule add ipproto tcp dport 465 table "$TABLE" 2>/dev/null || true
ip rule add ipproto tcp dport 587 table "$TABLE" 2>/dev/null || true

### 7. DNS-Handling (wichtig bei Multi-VPN) ###
echo "📡 Konfiguriere DNS..."
# Erzwinge DNS über physische Schnittstelle nur für SMTP
iptables -t nat -A OUTPUT -p udp --dport 53 -m set --match-set smtp_dst_ip dst -j DNAT --to $GATEWAY:53
iptables -t nat -A OUTPUT -p tcp --dport 53 -m set --match-set smtp_dst_ip dst -j DNAT --to $GATEWAY:53

### 8. Reverse Path Filtering ###
echo "🔄 Deaktiviere RPF für $INTERFACE..."
echo 0 > /proc/sys/net/ipv4/conf/$INTERFACE/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter

### 9. Statusausgabe ###
echo ""
echo "✅ SMTP-Routing für Table '$TABLE' abgeschlossen."
echo ""
echo "ℹ️ Aktive Einträge im ipset:"
ipset list smtp_dst_ip | grep -E '^[0-9]' | head -n 5
[ $(ipset list smtp_dst_ip | grep -E '^[0-9]' | wc -l) -gt 5 ] && echo "... (weitere Einträge vorhanden)"

echo ""
echo "🌐 Routing-Tabelle '$TABLE':"
ip route show table "$TABLE"

echo ""
echo "📡 Testen mit:"
echo "dig +short YOUR_MAIL_SERVER"
echo "telnet YOUR_MAIL_SERVER 25"
echo "curl --interface $INTERFACE ifconfig.me"
