#!/bin/bash
source /opt/mpvpn/globals.sh

# Sicherstellen, dass das Skript mit Root-Rechten ausgeführt wird
if [[ $EUID -ne 0 ]]; then
   echo "Dieses Skript muss als Root ausgeführt werden." 
   exit 1
fi

VPN_INTERFACES=("${WGVPN_LIST[@]}" "${OVPN_LIST[@]}")

# Vorhandene Regeln leeren
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

###Mangle###
# Routing-Markierungen für VPN-Interfaces setzen
for i in "${!VPN_INTERFACES[@]}"; do
    iface="${VPN_INTERFACES[$i]}"
    mark=$((i+1))

    echo "➡️  $iface bekommt fwmark $mark"

    iptables -t mangle -A OUTPUT -o "$iface" -m conntrack --ctstate NEW -j MARK --set-xmark 0x$mark/0xffffffff
    iptables -t mangle -A POSTROUTING -o "$iface" -m conntrack --ctstate NEW -j CONNMARK --set-xmark 0x$mark/0xffffffff
done

iptables -t mangle -A PREROUTING -j CONNMARK --restore-mark
iptables -t mangle -A POSTROUTING -m mark ! --mark 0 -j CONNMARK --save-mark
iptables -t mangle -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark

#Erlaube Ping
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

#iptables regeln für Ausnahmen
# Funktion: Hole Tabellennummer anhand des Namens (z. B. "clear")
get_table_id_by_name() {
    local name="$1"
    for entry in "${EXTRA_RT_TABLES[@]}"; do
        table_id="${entry%% *}"
        table_name="${entry#* }"
        if [[ "$table_name" == "$name" ]]; then
            echo "$table_id"
            return 0
        fi
    done
    return 1
}

# Hole die Tabellennummer für "clear"
CLEAR_TABLE_ID=$(get_table_id_by_name "clear")

if [[ -z "$CLEAR_TABLE_ID" ]]; then
    echo "❌ Tabelle 'clear' nicht gefunden in EXTRA_RT_TABLES."
    exit 1
fi

echo "⚙️  Setze PREROUTING-Regeln für Ausnahmen über Table $CLEAR_TABLE_ID..."

# PREROUTING für Ausnahmen
for ip in $(ip route show table "$CLEAR_TABLE_ID" | awk '{print $1}'); do
    echo "➕ Markiere Ziel-IP $ip mit fwmark $CLEAR_TABLE_ID"
    iptables -t mangle -A PREROUTING -d "$ip" -j MARK --set-mark "$CLEAR_TABLE_ID"
done

# Mail-Ports markieren
for port in 25 465 587 993 995; do
	iptables -t mangle -A OUTPUT -p tcp --dport $port -j MARK --set-mark 200
done

# Filter-Tabelle setzen
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 22,80,81,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
#iptables -A INPUT -p udp --dport 53 -j ACCEPT
#iptables -A INPUT -p tcp --dport 53 -j ACCEPT
#iptables -A INPUT -p udp -m udp --dport 67:69 -j ACCEPT
#iptables -A INPUT -p udp --dport 5335 -j ACCEPT
#iptables -A INPUT -p tcp --dport 5335 -j ACCEPT
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "IPTables-DROP: " --log-level 4
iptables -A INPUT -j DROP

for SRC in "${VPN_INTERFACES[@]}"; do
    for DST in "${VPN_INTERFACES[@]}"; do
        if [[ "$SRC" != "$DST" ]]; then
            iptables -A FORWARD -i "$SRC" -o "$DST" -j REJECT --reject-with icmp-port-unreachable
        fi
    done
done

# Definiere assoziatives Array für Interface-IP-Zuordnung
declare -A VPN_IPS

# IP-Adressen auslesen und dem Interface zuweisen
for iface in "${VPN_INTERFACES[@]}"; do
  ip=$(ip -4 addr show "$iface" | awk '/inet / {print $2}' | cut -d/ -f1)
  if [[ -n "$ip" ]]; then
    VPN_IPS["$iface"]="$ip"
  else
    echo "⚠️  Keine IPv4-Adresse gefunden für Interface $iface – wird übersprungen."
  fi
done

# Blockiere Pakete mit falscher Quell-IP auf dem VPN-Interface (Anti-Leak)
for iface in "${!VPN_IPS[@]}"; do
  for src_ip in "${VPN_IPS[@]}"; do
    if [[ "$src_ip" != "${VPN_IPS[$iface]}" ]]; then
      iptables -A OUTPUT -o "$iface" -m conntrack --ctorigsrc "$src_ip" -j REJECT --reject-with icmp-port-unreachable
    fi
  done
done

#Definiere Ausnahmen
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

# Setze iptables-Regeln für NON_VPN_CLIENTS mit diesem MARK
for ip in "${NON_VPN_CLIENTS[@]}"; do
    echo "➕ Setze Ausnahme für $ip mit Mark $MARK"
    iptables -t mangle -A PREROUTING -s "$ip" -j MARK --set-mark "$MARK"
done

# Killswitch für sicheres Routing
#iptables -N KILLSWITCH
#iptables -A OUTPUT -j KILLSWITCH
#iptables -A KILLSWITCH -o lo -j RETURN
#iptables -A KILLSWITCH -p tcp --dport 22 -j RETURN
#iptables -A KILLSWITCH -d 192.168.0.0/16 -j RETURN
#iptables -A KILLSWITCH -d 10.0.0.0/8 -j RETURN
#iptables -A KILLSWITCH -d 172.16.0.0/12 -j RETURN
#for iface in "${VPN_INTERFACES[@]}"; do
#  iptables -A KILLSWITCH -o $iface -j RETURN
#done

# NAT-Tabelle setzen
for iface in "${VPN_INTERFACES[@]}"; do
  iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
done

#iptables -t nat -A POSTROUTING -o enp1s0 -j MASQUERADE
iptables -t nat -A POSTROUTING -o enp1s0 -m mark --mark 100 -j MASQUERADE

for port in 25 465 587 993 995; do
  iptables -t nat -A POSTROUTING -o enp1s0 -p tcp --dport $port -j MASQUERADE
done

# Regeln speichern
iptables-save > /etc/sysconfig/iptables

echo "iptables-Regeln wurden erfolgreich angewendet und gespeichert."
