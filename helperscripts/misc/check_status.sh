#!/bin/bash

echo "=============================="
echo "Aktive 'ip rule'-Regeln:"
echo "=============================="
ip rule list
echo

echo "=============================="
echo "Aktive 'ip route'-Tabellen (custom):"
echo "=============================="
for entry in $(grep -v '^#' /etc/iproute2/rt_tables | awk '{print $2}'); do
    echo ">>> Tabelle: $entry"
    ip route show table "$entry"
    echo
done

echo "=============================="
echo "Aktive iptables-Regeln (Mangle/PREROUTING):"
echo "=============================="
iptables -t mangle -L PREROUTING -n -v --line-numbers
echo

echo "=============================="
echo "Aktive iptables-Regeln (Mangle/OUTPUT):"
echo "=============================="
iptables -t mangle -L OUTPUT -n -v --line-numbers
echo

echo "=============================="
echo "Aktive ipsets (nur to_table_*):"
echo "=============================="
for set in $(ipset list -n | grep '^to_table_'); do
    echo ">>> ipset: $set"
    ipset list "$set" | grep -E 'Members|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'
    echo
done

echo "[OK] Systemstatus abgefragt."
