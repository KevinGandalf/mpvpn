#!/bin/bash
echo "Stoppe Killswitch"
systemctl stop killswitch

#Setze alle Counter zurück, lade iptables
sed -Ei 's/\[[0-9]+:[0-9]+\]/[0:0]/g' /etc/sysconfig/iptables
iptables-restore < /etc/sysconfig/iptables

#Prüfe ob nf_conntrack für iptables aktiv ist
echo "Lade Conntrack Modul für iptables..."
modprobe nf_conntrack

#Lade Sysctl
echo "Lade sysctl.conf..."
sysctl -p

#Lese Wireguard Configs aus
echo "Hole Endpoint Adressen und setze Route über Default Interface..."
/opt/mpvpn/helperscripts/misc/get_wgendpoints.sh
#Erhalte Surfshark Adressen
#echo "Prüfe Surfshark OpenVPN Adressen und setze Route über Default Interface..."
#/opt/mpvpn/get_surfshark.sh

#Starte Wireguard Verbindungen
echo "Starte Wireguard Verbindungen..."
wg-quick up vpn1
wg-quick up vpn2
wg-quick up vpn3
wg-quick up vpn4
#Starte OpenVPN
#echo "Starte OpenVPN Verbindungen tun0..."
#openvpn --config /etc/openvpn/nordvpn1.conf --daemon
#sleep 5
#rerun ip route del
#echo "Lösche mögliche Default Routen für tun0..."
#sudo ip route del 0.0.0.0/1 via 10.100.0.1 dev tun0
#sudo ip route del 128.0.0.0/1 via 10.100.0.1 dev tun0
#echo "Starte OpenVPN Verbindungen tun1..."
#openvpn --config /etc/openvpn/surfshark.conf --daemon
#sleep 5
#echo "Lösche mögliche Default Routen für tun1..."
#sudo ip route del 0.0.0.0/1 via 10.8.8.1 dev tun1
#sudo ip route del 128.0.0.0/1 via 10.8.8.1 dev tun1

echo "Räume /etc/iproute2/rt_tables auf..."
#Räume rt_tables auf
entries=("vpn1" "vpn2" "vpn3" "vpn4" "azirevpn" "cstorm" "ivpn" "pia" "surfshark" "nordovpn" "surfsharkovpn" "enp1s0only" "smtproute")

for entry in "${entries[@]}"; do
    sed -i "/^[0-9]\+ $entry$/d" /etc/iproute2/rt_tables
done

echo "Einträge wurden entfernt."

echo "Aktiviere Multipathing..."
#Aktiviere Nexthop für Loadbalancing
sudo ip route add default \
	nexthop dev vpn1 weight 1 \
	nexthop dev vpn2 weight 1 \
	nexthop dev vpn3 weight 1 \
    nexthop dev vpn4 weight 1 

echo "Schreibe Routing Tables..."
echo "1 vpn1" | sudo tee -a /etc/iproute2/rt_tables
echo "2 vpn2" | sudo tee -a /etc/iproute2/rt_tables
echo "3 vpn3" | sudo tee -a /etc/iproute2/rt_tables
echo "4 vpn4" | sudo tee -a /etc/iproute2/rt_tables
echo "100 enp1s0only" | sudo tee -a /etc/iproute2/rt_tables
echo "200 smtproute" | sudo tee -a /etc/iproute2/rt_tables

echo "Setze fwmatk..."
sudo ip rule add fwmark 1 lookup main
sudo ip rule add fwmark 2 lookup main
sudo ip rule add fwmark 3 lookup main
sudo ip rule add fwmark 4 lookup main

#IP Rule Ausnahmen Table 100 über enp1s0 --> 192.168.10.1
echo "Setze Ausnahmen auf Table 100..."
/opt/mpvpn/helperscripts/routes/set_enp1s0only.sh

#Ausnahmen SMTP etc.
echo "Setze Table 200..."
/opt/mpvpn/helperscripts/routes/set_smtproutes.sh

#Erhalte IP-Adressen zu diversen Mail Domänen, mit Output
echo "Besorge IP-Adressen von diversen Mail Diensten..."
/opt/mpvpn/helperscripts/splitdns/get_mailserver.sh

#echo "Lösche mögliche Default Routen für tun0 ubd tun1..."
#sudo ip route del 0.0.0.0/1 via 10.100.0.1 dev tun0
##sudo ip route del 128.0.0.0/1 via 10.100.0.1 dev tun0
#sudo ip route del 0.0.0.0/1 via 10.8.8.1 dev tun1
#sudo ip route del 128.0.0.0/1 via 10.8.8.1 dev tun1

echo "Setze iptables zurück und stelle Regeln wieder her..."
/opt/mpvpn/helperscripts/iptables_script.sh

echo "Starte Killswitch..."
systemctl start killswitch

echo "Prüfe Verbindungen..."
/opt/mpvpn/helperscripts/check_connection.sh
tail -n 10 /var/log/vpn_ip_log.txt
sleep 3
echo "Einrichtung SplitDNS, bitte warten...."
/opt/mpvpn/helperscripts/splitdns/get_streaming.sh
/opt/mpvpn/helperscripts/splitdns/get_splitdnsdomains.sh

echo "...Have Fun!..."
