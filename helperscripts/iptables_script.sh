#!/bin/bash
source /opt/mpvpn/globals.sh

# Ensure root execution
if [[ $EUID -ne 0 ]]; then
   echo "Dieses Skript muss als Root ausgeführt werden." 
   exit 1
fi

VPN_INTERFACES=("${WGVPN_LIST[@]}" "${OVPN_LIST[@]}")

# Clear existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

### Mangle Table - Packet Marking ###
# Restore connection marks early
iptables -t mangle -A PREROUTING -j CONNMARK --restore-mark

# Mark new connections per VPN interface
# Schleife über VPN_INTERFACES (wie gehabt)
for i in "${!VPN_INTERFACES[@]}"; do
    iface="${VPN_INTERFACES[$i]}"
    mark=$((i+1))

    echo "➡️  $iface bekommt fwmark $mark"
    
    # IP des Interfaces holen
    ip=$(ip -4 addr show "$iface" | awk '/inet / {print $2}' | cut -d/ -f1)
    if [[ -n "$ip" ]]; then
        iptables -A OUTPUT -o "$iface" ! -s "$ip" -j DROP
    fi

    # Verbindung markieren
    iptables -t mangle -A OUTPUT -o "$iface" -m conntrack --ctstate NEW -j MARK --set-xmark 0x$mark/0xffffffff
    iptables -t mangle -A POSTROUTING -o "$iface" -m conntrack --ctstate NEW -j CONNMARK --set-xmark 0x$mark/0xffffffff
done   # <-- Hier das Ende der äußeren Schleife

for i in "${!VPN_INTERFACES[@]}"; do
    iface="${VPN_INTERFACES[$i]}"
    mark=$((i+1))

    echo "➡️  $iface bekommt fwmark $mark"

    # IP des Interfaces holen
    ip=$(ip -4 addr show "$iface" | awk '/inet / {print $2}' | cut -d/ -f1)
    if [[ -n "$ip" ]]; then
        iptables -A OUTPUT -o "$iface" ! -s "$ip" -j DROP
    fi

    # Verbindung markieren
    iptables -t mangle -A OUTPUT -o "$iface" -m conntrack --ctstate NEW -j MARK --set-xmark 0x$mark/0xffffffff
    iptables -t mangle -A POSTROUTING -o "$iface" -m conntrack --ctstate NEW -j CONNMARK --set-xmark 0x$mark/0xffffffff

    # Extrahiere den Basisnamen des Interfaces (z. B. mullvad1 -> mullvad)
    base_iface="${iface%%[0-9]*}"
    varname="DNS_${base_iface^^}"  # z. B. DNS_MULLVAD
    dns_ips="${!varname}"

    if [[ -n "$dns_ips" ]]; then
        IFS=',' read -ra ip_array <<< "$dns_ips"
        for dns_ip in "${ip_array[@]}"; do
            echo "🧠  Setze DNS-Regel für $iface → $dns_ip (fwmark $mark)"
            iptables -t mangle -A OUTPUT -o "$iface" -p udp --dport 53 -d "$dns_ip" -j MARK --set-mark "$mark"
            iptables -t mangle -A OUTPUT -o "$iface" -p tcp --dport 53 -d "$dns_ip" -j MARK --set-mark "$mark"
        done
    else
        echo "⚠️  Keine DNS-IPs definiert für $iface ($varname)"
    fi
done


# Save marks for established connections
iptables -t mangle -A POSTROUTING -m mark ! --mark 0 -j CONNMARK --save-mark
iptables -t mangle -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark

### Exception Handling ###
# Get clear table ID
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

CLEAR_TABLE_ID=$(get_table_id_by_name "clear") || {
    echo "❌ Tabelle 'clear' nicht gefunden in EXTRA_RT_TABLES."
    exit 1
}

echo "⚙️  Setze PREROUTING-Regeln für Ausnahmen über Table $CLEAR_TABLE_ID..."

# Mark traffic for clear table
for ip in "${NON_VPN_CLIENTS[@]}"; do
    echo "➕ Setze Ausnahme für $ip mit Mark $CLEAR_TABLE_ID"
    iptables -t mangle -A PREROUTING -s "$ip" -j MARK --set-mark "$CLEAR_TABLE_ID"
done

# Mark mail ports
for port in 25 465 587 993 995; do
    iptables -t mangle -A OUTPUT -p tcp --dport $port -j MARK --set-mark 200
done

### Filter Table ###
# Basic firewall rules
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 22,80,81,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i enp1s0 -p udp --dport 53 -s 192.168.10.0/24 -j ACCEPT
iptables -A INPUT -i enp1s0 -p tcp --dport 53 -s 192.168.10.0/24 -j ACCEPT
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "IPTables-DROP: " --log-level 4
iptables -A INPUT -j DROP

# Prevent cross-VPN traffic
for SRC in "${VPN_INTERFACES[@]}"; do
    for DST in "${VPN_INTERFACES[@]}"; do
        if [[ "$SRC" != "$DST" ]]; then
            iptables -A FORWARD -i "$SRC" -o "$DST" -j REJECT --reject-with icmp-port-unreachable
        fi
    done
done

### NAT Rules ###
# VPN MASQUERADE
for iface in "${VPN_INTERFACES[@]}"; do
    iptables -t nat -A POSTROUTING -o "$iface" -j MASQUERADE
done

# Save rules
iptables-save > /etc/sysconfig/iptables

echo "iptables-Regeln wurden erfolgreich optimiert und gespeichert."
