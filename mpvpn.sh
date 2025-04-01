#!/bin/bash
#systemctl start unbound
echo "Stoppe Killswitch"
systemctl stop killswitch

echo "Stoppe systemd-resolved..."
systemctl stop systemd-resolved
echo "Restarte pihole-FTL + systemd-resolved...."
systemctl restart pihole-FTL
systemctl start systemd-resolved

#Prüfe ob nf_conntrack für iptables aktiv ist
echo "Lade Conntrack Modul für iptables..."
modprobe nf_conntrack

#Lade Sysctl
echo "Lade sysctl.conf..."
sysctl -p

#Lese Wireguard Configs aus
echo "Hole Endpoint Adressen und setze Route über Default Interface..."
/opt/mpvpn/scripts/get_wgendpoints.sh
#Erhalte Surfshark Adressen
echo "Prüfe Surfshark OpenVPN Adressen und setze Route über Default Interface..."
/opt/mpvpn/scripts/get_surfshark.sh

#Starte Wireguard Verbindungen
echo "Starte Wireguard Verbindungen..."
wg-quick up mullvad1
wg-quick up mullvad2
wg-quick up azirevpn1
wg-quick up azirevpn2
wg-quick up deubau
wg-quick up ivpn
wg-quick up pia
wg-quick up nordvpn
wg-quick up surfshark
#Starte OpenVPN
echo "Starte OpenVPN Verbindungen tun0..."
openvpn --config /etc/openvpn/nordvpn1.conf --daemon
sleep 5
#rerun ip route del
echo "Lösche mögliche Default Routen für tun0..."
sudo ip route del 0.0.0.0/1 via 10.100.0.1 dev tun0
sudo ip route del 128.0.0.0/1 via 10.100.0.1 dev tun0
echo "Starte OpenVPN Verbindungen tun1..."
openvpn --config /etc/openvpn/surfshark.conf --daemon
sleep 5
echo "Lösche mögliche Default Routen für tun1..."
sudo ip route del 0.0.0.0/1 via 10.8.8.1 dev tun1
sudo ip route del 128.0.0.0/1 via 10.8.8.1 dev tun1

echo "Räume /etc/iproute2/rt_tables auf..."
#Räume rt_tables auf
entries=("mullvad1" "mullvad2" "nordvpn" "azirevpn1" "azirevpn2" "cstorm" "ivpn" "pia" "surfshark" "nordovpn" "surfsharkovpn" "enp1s0only" "smtproute")

for entry in "${entries[@]}"; do
    sed -i "/^[0-9]\+ $entry$/d" /etc/iproute2/rt_tables
done

echo "Einträge wurden entfernt."

echo "Aktiviere Multipathing..."
#Aktiviere Nexthop für Loadbalancing
sudo ip route add default \
        nexthop dev mullvad1 weight 1 \
        nexthop dev mullvad2 weight 1 \
        nexthop dev azirevpn1 weight 1 \
        nexthop dev azirevpn2 weight 1 \
        nexthop dev ivpn weight 1 \
        nexthop dev pia weight 1 \
        nexthop dev nordvpn weight 1 \
        nexthop dev surfshark weight 1 \
        nexthop via 10.100.0.1 dev tun0 weight 1 \
        nexthop via 10.8.8.1 dev tun1 weight 1

echo "Schreibe Routing Tables..."
echo "1 mullvad1" | sudo tee -a /etc/iproute2/rt_tables
echo "2 mullvad2" | sudo tee -a /etc/iproute2/rt_tables
echo "3 azirevpn1" | sudo tee -a /etc/iproute2/rt_tables
echo "4 azirevpn2" | sudo tee -a /etc/iproute2/rt_tables
echo "5 ivpn" | sudo tee -a /etc/iproute2/rt_tables
echo "6 pia" | sudo tee -a /etc/iproute2/rt_tables
echo "7 nordvpn" | sudo tee -a /etc/iproute2/rt_tables
echo "8 surfshark" | sudo tee -a /etc/iproute2/rt_tables
echo "9 nordovpn" | sudo tee -a /etc/iproute2/rt_tables
echo "10 surfsharkovpn" | sudo tee -a /etc/iproute2/rt_tables
echo "100 enp1s0only" | sudo tee -a /etc/iproute2/rt_tables
echo "200 smtproute" | sudo tee -a /etc/iproute2/rt_tables

echo "Setze fwmatk..."
sudo ip rule add fwmark 1 lookup main
sudo ip rule add fwmark 2 lookup main
sudo ip rule add fwmark 3 lookup main
sudo ip rule add fwmark 4 lookup main
sudo ip rule add fwmark 5 lookup main
sudo ip rule add fwmark 6 lookup main
sudo ip rule add fwmark 7 lookup main
sudo ip rule add fwmark 8 lookup main
sudo ip rule add fwmark 9 lookup main
sudo ip rule add fwmark 10 lookup main

#IP Rule Ausnahmen Table 100 über enp1s0 --> 192.168.10.1
#echo "Setze Ausnahmen auf Table 100..."
#ip rule add fwmark 100 table 100
#ip route add default via 192.168.10.1 dev enp1s0 table 100
#ip rule add from 192.168.10.167 table 100
#ip rule add from 192.168.10.167 prohibit
#ip rule add from 192.168.10.164 table 100
#ip rule add from 192.168.10.164 prohibit
#ip rule add from 192.168.10.61 table 100
#ip rule add from 192.168.10.61 prohibit
#ip rule add from 192.168.10.51 table 100
#ip rule add from 192.168.10.51 prohibit
#iptables -t mangle -A PREROUTING -s 192.168.10.167 -j MARK --set-mark 100
#iptables -t mangle -A PREROUTING -s 192.168.10.164 -j MARK --set-mark 100
#iptables -t mangle -A PREROUTING -s 192.168.10.61 -j MARK --set-mark 100
#iptables -t mangle -A PREROUTING -s 192.168.10.51 -j MARK --set-mark 100

#Erhalte IP-Adressen zu diversen Mail Domänen, mit Output
echo "Besorge IP-Adressen von diversen Mail Diensten und setze routen..."
/opt/mpvpn/scripts/get_mailserver.sh

# Setze DNS um DNS Leaks zu vermeiden
#ip rule add to 194.242.2.3 table mullvad1
#ip rule add to 100.64.0.7 table mullvad1
#ip rule add to 10.64.0.1 table mullvad2
#ip rule add to 91.231.153.2 table azirevpn1
#ip rule add to 10.0.0.1 table mullvad2
#ip rule add to 91.231.153.2 table azirevpn
#ip rule add to 10.0.0.1 table azirevpn2
#ip rule add to 103.86.96.100 table nordvpn
#ip rule add to 103.86.99.100 table nordvpn
#ip rule add to 10.31.33.7 table cstorm
#ip rule add to 172.16.0.1 table ivpn
#ip rule add to 10.0.0.243 table pia
#rerun ip route del
echo "Lösche mögliche Default Routen für tun0 ubd tun1..."
sudo ip route del 0.0.0.0/1 via 10.100.0.1 dev tun0
sudo ip route del 128.0.0.0/1 via 10.100.0.1 dev tun0
sudo ip route del 0.0.0.0/1 via 10.8.8.1 dev tun1
sudo ip route del 128.0.0.0/1 via 10.8.8.1 dev tun1

echo "Setze Counter für iptables zurück und stelle Regeln wieder her..."
/opt/mpvpn/scripts/iptables_script.sh
#Setze alle Counter zurück, lade iptables
sed -Ei 's/\[[0-9]+:[0-9]+\]/[0:0]/g' /etc/sysconfig/iptables
iptables-restore < /etc/sysconfig/iptables

echo "Starte Killswitch..."
systemctl start killswitch

echo "Prüfe Verbindungen..."
cat /var/log/vpn_ip_log.txt

echo "...Have Fun!..."
