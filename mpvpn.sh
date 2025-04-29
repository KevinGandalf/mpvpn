#!/bin/bash
# systemctl start unbound
export BASE_PATH=/opt/mpvpn
source $BASE_PATH/globals.conf

# Betriebssystem erkennen
if [[ -f /etc/debian_version ]]; then
    IPTABLES_RULES_FILE="/etc/iptables/rules.v4"
elif [[ -f /etc/redhat-release || -f /etc/centos-release || -f /etc/almalinux-release ]]; then
    IPTABLES_RULES_FILE="/etc/sysconfig/iptables"
else
    echo "❌ Unbekanntes Betriebssystem. Skript wird beendet."
    exit 1
fi

# Setze alle Counter zurück
echo "🔄 Setze Zähler in $IPTABLES_RULES_FILE zurück..."
sed -Ei 's/\[[0-9]+:[0-9]+\]/[0:0]/g' "$IPTABLES_RULES_FILE"

# Lade iptables-Regeln
echo "♻️  Lade iptables-Regeln aus $IPTABLES_RULES_FILE..."
iptables-restore < "$IPTABLES_RULES_FILE"

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
echo "Setze Routing Tables..."
/opt/mpvpn/helperscripts/startup/addroutingtables.sh
/opt/mpvpn/helperscripts/startup/set_wgroute_to_table.sh

#FWMARK
/opt/mpvpn/helperscripts/startup/addfwmark.sh

echo "Setze FWMARKs und Routing Regeln..."
/opt/mpvpn/routes/set_routingrules.sh
#Erhalte IP-Adressen zu diversen Mail Domänen, mit Output
echo "Besorge IP-Adressen von diversen Mail Diensten..."
/opt/mpvpn/helperscripts/splitdns/get_mailserver.sh

echo "Setze iptables zurück und stelle Regeln wieder her..."
/opt/mpvpn/helperscripts/iptables_script.sh

#echo "Starte Killswitch..."
#systemctl start killswitch

echo "Prüfe Verbindungen..."
/opt/mpvpn/helperscripts/misc/check_connection.sh
tail -n 10 /var/log/vpn_ip_log.txt
sleep 3
echo "Einrichtung SplitDNS"
/opt/mpvpn/helperscripts/splitdns/get_streaming.sh
/opt/mpvpn/helperscripts/splitdns/get_splitdnsdomain.sh
echo "Generiere IPSETS..."
/opt/mpvpn/helperscripts/generate_ipsets.sh --apply
#echo "Starte Unbound neu..."
#systemctl restart unbound

echo "...Have Fun!..."
