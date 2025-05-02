#!/bin/bash
# VPN-Bypass-Skript für spezifische Domains
# Version 3.3 - Verbesserte MASQUERADE-Prüfung

### Konfiguration ###
source /opt/mpvpn/globals.conf
DOMAIN=$1
ROUTE_TABLE=900
DNS_SERVERS="8.8.8.8 1.1.1.1 9.9.9.9"

### VPN Interfaces aus globals.conf ###
VPN_INTERFACES=()
if [[ -n "$WG_LIST" ]]; then
  IFS=',' read -ra WG_IFACES <<< "$WG_LIST"
  VPN_INTERFACES+=("${WG_IFACES[@]}")
fi

if [[ "$ENABLE_OVPN" == "true" && -n "$OVPN_LIST" ]]; then
  IFS=',' read -ra OVPN_IFACES <<< "$OVPN_LIST"
  VPN_INTERFACES+=("${OVPN_IFACES[@]}")
fi

echo "🛡️ Aktive VPN-Interfaces: ${VPN_INTERFACES[*]}"

### Überprüfungen ###
if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain>"
  echo "Beispiel: $0 wieistmeineip.de"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Das Skript benötigt root-Rechte!"
  exit 1
fi

### 1. Bereinigung bestehender Regeln ###
echo "Bereinige bestehende Regeln..."
ipset list vpn_bypass_dst_ip &>/dev/null && ipset destroy vpn_bypass_dst_ip
iptables -t mangle -D PREROUTING -m set --match-set vpn_bypass_dst_ip dst -j MARK --set-mark 900 2>/dev/null
iptables -t mangle -D OUTPUT -m set --match-set vpn_bypass_dst_ip dst -j MARK --set-mark 900 2>/dev/null
iptables -t nat -D OUTPUT -p udp --dport 53 -j DNAT --to $DEFAULT_WANGW:53 2>/dev/null
iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNAT --to $DEFAULT_WANGW:53 2>/dev/null
ip rule del fwmark 900 2>/dev/null
ip route flush table $ROUTE_TABLE 2>/dev/null

### 2. ipset erstellen ###
echo "Erstelle ipset..."
ipset create vpn_bypass_dst_ip hash:net timeout 0 2>/dev/null || ipset flush vpn_bypass_dst_ip

### 3. DNS-Auflösung ###
echo "Resolve DNS für $DOMAIN..."
declare -A unique_ips

for server in $DNS_SERVERS; do
  echo " - Verwende DNS-Server $server"
  getent ahosts $DOMAIN @$server | awk '{print $1}' | sort -u | while read ip; do
    if [ -z "${unique_ips[$ip]}" ]; then
      unique_ips[$ip]=1
      echo "   + Füge IP $ip hinzu"
      ipset add vpn_bypass_dst_ip "$ip" 2>/dev/null || echo "   ! IP bereits vorhanden"
      
      # VPN-Routen für diese IP entfernen
      for vpn in "${VPN_INTERFACES[@]}"; do
        if ip link show "$vpn" >/dev/null 2>&1; then
          ip route del "$ip" dev "$vpn" 2>/dev/null && \
          echo "   ✗ Route von $vpn entfernt" || true
        fi
      done
    fi
  done
done

### 4. Routing-Tabelle ###
echo "Konfiguriere Routing..."
if ! grep -q "$ROUTE_TABLE" /etc/iproute2/rt_tables; then
  echo "$ROUTE_TABLE vpn_bypass" >> /etc/iproute2/rt_tables
fi

### 5. Routing-Regeln ###
ip rule add fwmark 900 table $ROUTE_TABLE 2>/dev/null || echo "! Regel existiert bereits"
ip route add default via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table $ROUTE_TABLE 2>/dev/null || echo "! Standardroute existiert bereits"

### 6. Explizite Routen für jede IP ###
echo "Erstelle spezifische Routen..."
for ip in $(ipset list vpn_bypass_dst_ip | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' | sort -u); do
  ip route add "$ip" via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table $ROUTE_TABLE 2>/dev/null || echo "   ! Route für $ip existiert bereits"
  ip route add "$ip" via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" 2>/dev/null || echo "   ! Route für $ip existiert bereits"
done

### 7. iptables-Regeln ###
echo "Setze iptables-Regeln..."
# Markierung für ein- und ausgehenden Traffic
iptables -t mangle -A PREROUTING -m set --match-set vpn_bypass_dst_ip dst -j MARK --set-mark 900
iptables -t mangle -A OUTPUT -m set --match-set vpn_bypass_dst_ip dst -j MARK --set-mark 900

# MASQUERADE-Regel nur wenn nicht vorhanden
if ! iptables -t nat -C POSTROUTING -o "$DEFAULT_LANIF" -j MASQUERADE 2>/dev/null; then
  iptables -t nat -A POSTROUTING -o "$DEFAULT_LANIF" -j MASQUERADE && \
    echo "   ✓ MASQUERADE-Regel hinzugefügt" || \
    echo "   ! Fehler beim Hinzufügen der MASQUERADE-Regel"
else
  echo "   ✓ MASQUERADE-Regel existiert bereits"
fi

### 8. Metriken für Standardrouten ###
ip route add default via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" metric 100 2>/dev/null || echo "! Standardroute existiert bereits"
for vpn in "${VPN_INTERFACES[@]}"; do
  if ip link show "$vpn" >/dev/null 2>&1; then
    VPN_GATEWAY=$(ip route show dev "$vpn" | awk '/default/ {print $3}')
    if [ -n "$VPN_GATEWAY" ]; then
      if ! ip route | grep -q "default via $VPN_GATEWAY dev $vpn metric 200"; then
        ip route add default via "$VPN_GATEWAY" dev "$vpn" metric 200 2>/dev/null && \
          echo "   ✓ VPN-Route für $vpn hinzugefügt" || \
          echo "   ! Fehler bei VPN-Route für $vpn"
      else
        echo "   ✓ VPN-Route für $vpn existiert bereits"
      fi
    else
      echo "   ! VPN-Gateway für $vpn nicht gefunden"
    fi
  fi
done

### 9. Deaktiviere Reverse Path Filtering ###
[ -e "/proc/sys/net/ipv4/conf/$DEFAULT_LANIF/rp_filter" ] && echo 0 > "/proc/sys/net/ipv4/conf/$DEFAULT_LANIF/rp_filter"
[ -e "/proc/sys/net/ipv4/conf/all/rp_filter" ] && echo 0 > "/proc/sys/net/ipv4/conf/all/rp_filter"

### 10. Statusausgabe ###
echo ""
echo "=== Konfiguration abgeschlossen ==="
echo "Gefundene IPs für $DOMAIN:"
ipset list vpn_bypass_dst_ip | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' | sort -u

echo ""
echo "Aktive Routen in Tabelle $ROUTE_TABLE:"
ip route show table $ROUTE_TABLE 2>/dev/null || echo "Keine Routen in Tabelle $ROUTE_TABLE gefunden"

echo ""
echo "VPN-Interfaces behandelt: ${VPN_INTERFACES[*]}"

echo ""
echo "Testen mit:"
echo "curl --interface $DEFAULT_LANIF https://$DOMAIN"
echo "oder"
echo "dig +short $DOMAIN @$DEFAULT_WANGW"

exit 0
