#!/bin/bash
source $BASE_PATH/globals.conf

# Ensure root execution
if [[ $EUID -ne 0 ]]; then
   echo "Dieses Skript muss als Root ausgeführt werden." 
   exit 1
fi

# Lade Distributionserkennung
source /etc/os-release
DISTRO_ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
DISTRO_NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')

# 🧠 Erkenne Raspbian genauer
if echo "$DISTRO_NAME" | grep -q "raspbian"; then
    DISTRO_ID="raspbian"
fi

# 🔍 Zusätzlicher Check für Raspberry Pi OS
if [[ -f /boot/firmware/config.txt ]]; then
    DISTRO_ID="raspbian"
fi

# 💾 Auswahl des iptables-Speicherpfads
case "$DISTRO_ID" in
    ubuntu|debian|raspbian)
        SAVEFILE="/etc/iptables/rules.v4"
        ;;
    centos|rhel|almalinux|rocky)
        SAVEFILE="/etc/sysconfig/iptables"
        ;;
    *)
        echo "⚠️  Distribution '$DISTRO_ID' nicht erkannt. Verwende /etc/sysconfig/iptables als Fallback."
        SAVEFILE="/etc/sysconfig/iptables"
        ;;
esac


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
#iptables -t mangle -A PREROUTING -j CONNMARK --restore-mark
iptables -t mangle -A PREROUTING -j CONNMARK --restore-mark --nfmask 0xffffffff --ctmask 0xffffffff

for i in "${!VPN_INTERFACES[@]}"; do
    iface="${VPN_INTERFACES[$i]}"
    mark=$((i+1))
    
    echo "➡️  $iface bekommt fwmark $mark"
    
    iptables -t mangle -A OUTPUT -o "$iface" -m conntrack --ctstate NEW -j MARK --set-xmark 0x$mark/0xffffffff
    iptables -t mangle -A POSTROUTING -o "$iface" -m conntrack --ctstate NEW -j CONNMARK --set-xmark 0x$mark/0xffffffff
    
    ip=$(ip -4 addr show "$iface" | awk '/inet / {print $2}' | cut -d/ -f1)
    if [[ -n "$ip" ]]; then
        iptables -A OUTPUT -o "$iface" ! -s "$ip" -j DROP
    fi
done

iptables -t mangle -A POSTROUTING -m mark ! --mark 0 -j CONNMARK --save-mark
iptables -t mangle -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j CONNMARK --restore-mark

### Exception Handling ###
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

for ip in "${NON_VPN_CLIENTS[@]}"; do
    echo "➕ Setze Ausnahme für $ip mit Mark $CLEAR_TABLE_ID"
    iptables -t mangle -A PREROUTING -s "$ip" -j MARK --set-mark "$CLEAR_TABLE_ID"
done

# Mailports markieren
for port in 25 465 587 993 995; do
    iptables -t mangle -A OUTPUT -p tcp --dport "$port" -j MARK --set-mark 200
done

### Filter Table ###
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
# Bei einem Port:
#iptables -A INPUT -p tcp --dport "$PORTS_TCP" -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
# Bei mehreren Ports:
iptables -A INPUT -p tcp -m multiport --dports "$PORTS_TCP" -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
# Bei einem Port:
iptables -A INPUT -p udp --dport "$PORTS_UDP" -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
# Bei mehreren Ports:
#iptables -A INPUT -p udp -m multiport --dports "$PORTS_UDP" -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "IPTables-DROP: " --log-level 4
iptables -A INPUT -j DROP

# Cross-VPN Block
for SRC in "${VPN_INTERFACES[@]}"; do
    for DST in "${VPN_INTERFACES[@]}"; do
        if [[ "$SRC" != "$DST" ]]; then
            iptables -A FORWARD -i "$SRC" -o "$DST" -j REJECT --reject-with icmp-port-unreachable
        fi
    done
done

### NAT ###
for iface in "${VPN_INTERFACES[@]}"; do
    iptables -t nat -A POSTROUTING -o "$iface" -j MASQUERADE
done
iptables -t nat -A POSTROUTING -o $DEFAULT_LANIF -j MASQUERADE

### Speichern ###
echo "💾 Speichere Regeln nach $SAVEFILE"
iptables-save > "$SAVEFILE"

echo "✅ iptables-Regeln erfolgreich konfiguriert und gespeichert."
