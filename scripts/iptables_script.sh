!/bin/bash

# Sicherstellen, dass das Skript mit Root-Rechten ausgeführt wird
if [[ $EUID -ne 0 ]]; then
   echo "Dieses Skript muss als Root ausgeführt werden." 
   exit 1
fi

# Gateway und Interface für Regeln
GATEWAY="192.168.10.1"
INTERFACE="enp1s0"

VPN_INTERFACES=("mullvad1" "mullvad2" "azirevpn1" "azirevpn2" "ivpn" "pia" "nordvpn" "surfshark" "tun0" "tun1")

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
    mark=$((i+1))
    iptables -t mangle -A OUTPUT -o "${VPN_INTERFACES[$i]}" -m conntrack --ctstate NEW -j MARK --set-xmark 0x$mark/0xffffffff
    iptables -t mangle -A POSTROUTING -m conntrack --ctstate NEW -j CONNMARK --set-xmark 0x$mark/0xffffffff
done
iptables -t mangle -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark

#Erlaube Ping
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# Mail-Ports markieren
for port in 25 465 587 993 995; do
  iptables -t mangle -A OUTPUT -p tcp --dport $port -j MARK --set-mark 0x200
done

# Filter-Tabelle setzen
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 22,80,81,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp -m udp --dport 67:69 -j ACCEPT
#iptables -A INPUT -p udp --dport 5335 -j ACCEPT
#iptables -A INPUT -p tcp --dport 5335 -j ACCEPT
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "IPTables-DROP: " --log-level 4
iptables -A INPUT -j DROP

# VPN-Schnittstellen isolieren
#VPN_INTERFACES=("mullvad1" "mullvad2" "azirevpn1" "azirevpn2" "nordvpn" "cstorm" "ivpn")

for SRC in "${VPN_INTERFACES[@]}"; do
    for DST in "${VPN_INTERFACES[@]}"; do
        if [[ "$SRC" != "$DST" ]]; then
            iptables -A FORWARD -i "$SRC" -o "$DST" -j REJECT --reject-with icmp-port-unreachable
        fi
    done
done

# Definiere die VPN-Interfaces und ihre zugehörigen IP-Adressen
declare -A VPN_IPS

# Liste der VPN-Interfaces
INTERFACES=(
  mullvad1
  mullvad2
  azirevpn1
  azirevpn2
  ivpn
  pia
  nordvpn
  surfshark
  tun0
  tun1
)

# IP-Adressen auslesen und in das Array einfügen
for iface in "${INTERFACES[@]}"; do
  ip=$(ip -4 addr show "$iface" | awk '/inet / {print $2}' | cut -d/ -f1)
  if [[ -n "$ip" ]]; then
    VPN_IPS["$iface"]="$ip"
  fi
done

# Blockiere Pakete mit einer falschen Quell-IP auf den jeweiligen VPN-Schnittstellen
for iface in "${!VPN_IPS[@]}"; do
  for src_ip in "${VPN_IPS[@]}"; do
    if [[ "$src_ip" != "${VPN_IPS[$iface]}" ]]; then
      iptables -A OUTPUT -o "$iface" -m conntrack --ctorigsrc "$src_ip" -j REJECT --reject-with icmp-port-unreachable
    fi
  done
done


#Definiere Ausnahmen
#iptables -t mangle -A PREROUTING -s 192.168.10.167 -j MARK --set-mark 100
#iptables -t mangle -A PREROUTING -s 192.168.10.164 -j MARK --set-mark 100
#iptables -t mangle -A PREROUTING -s 192.168.10.61 -j MARK --set-mark 100
#iptables -t mangle -A PREROUTING -s 192.168.10.51 -j MARK --set-mark 100

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
for port in 25 465 587 993 995; do
  iptables -t nat -A POSTROUTING -o $INTERFACE -p tcp --dport $port -j MASQUERADE
done

# Regeln speichern
iptables-save > /etc/sysconfig/iptables

echo "iptables-Regeln wurden erfolgreich angewendet und gespeichert."
