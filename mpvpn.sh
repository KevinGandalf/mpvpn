#!/bin/bash
#systemctl start unbound
source /opt/mpvpn/globals.sh
#echo "Stoppe Killswitch"
#systemctl stop killswitch

#Setze alle Counter zurück, lade iptables
sed -Ei 's/\[[0-9]+:[0-9]+\]/[0:0]/g' /etc/sysconfig/iptables
#iptables-restore < /etc/sysconfig/iptables

#/opt/mpvpn/iptables_script.sh
#echo "Stoppe systemd-resolved..."
#systemctl stop systemd-resolved
#echo "Restarte pihole-FTL + systemd-resolved...."
#systemctl restart pihole-FTL
#systemctl start systemd-resolved

#Prüfe ob nf_conntrack für iptables aktiv ist
echo "Lade Conntrack Modul für iptables..."
modprobe nf_conntrack

#Lade Sysctl
echo "Lade sysctl.conf..."
sysctl -p

#Lese Wireguard Configs aus
echo "Hole Endpoint Adressen und setze Route über Default Interface..."
/opt/mpvpn/helperscripts/misc/get_wgendpoints.sh

###Wenn Surfshark genutzt wird!###
#Erhalte Surfshark Adressen
#echo "Prüfe Surfshark OpenVPN Adressen und setze Route über Default Interface..."
#/opt/mpvpn/helperscripts/misc/get_surfshark.sh

#Starte Wireguard Verbindungen
/opt/mpvpn/helperscripts/startup/startwireguard.sh

if [ "$ENABLE_OVPN" = true ]; then
    echo "🔄 Starte alle OpenVPN-Verbindungen..."
    /opt/mpvpn/helperscripts/startup/startopenvpn.sh
else
    echo "🔒 OpenVPN ist deaktiviert – überspringe das Starten von OpenVPN."
fi

#Bereinige Routing Tables
/opt/mpvpn/helperscripts/startup/cleanuprt.sh

#Aktiviere Multipathing
/opt/mpvpn/helperscripts/startup/startmp.sh

#ROUTING TABLES
/opt/mpvpn/helperscripts/startup/addroutingtables.sh

#FWMARK
/opt/mpvpn/helperscripts/startup/addfwmark.sh

#IP Rule Ausnahmen Table 100 über enp1s0 --> 192.168.10.1
echo "Setze Ausnahmen auf Table 100..."
/opt/mpvpn/helperscripts/routes/set_clearnetonly.sh

#Ausnahmen SMTP etc.
echo "Setze Table 200..."
/opt/mpvpn/helperscripts/routes/set_smtproutes.sh

#Erhalte IP-Adressen zu diversen Mail Domänen, mit Output
echo "Besorge IP-Adressen von diversen Mail Diensten..."
/opt/mpvpn/helperscripts/splitdns/get_mailsrv.sh

echo "Setze iptables zurück und stelle Regeln wieder her..."
/opt/mpvpn/helperscripts/iptables_script.sh

#echo "Starte Killswitch..."
#systemctl start killswitch

echo "Prüfe Verbindungen..."
/opt/mpvpn/helperscripts/curl2.sh
tail -n 10 /var/log/vpn_ip_log.txt
sleep 3
echo "Einrichtung SplitDNS"
/opt/mpvpn/helperscripts/splitdns/get_splitdns.sh
/opt/mpvpn/helperscripts/splitdns/get_splitdnsdomains.sh

echo "...Have Fun!..."
