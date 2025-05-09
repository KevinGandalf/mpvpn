![MPVPN Logo](mpvpn_logo_klein.png)

## Installationsscript:
```bash
#Ubuntu / Debian
sudo apt install wget && sudo bash -c "$(wget -qO- https://kevingandalf.github.io/mpvpn/mpvpn-install)"

#Almalinux, RHEL, Rocky, CentOS etc.
dnf install -y wget && sudo bash -c "$(wget -qO- https://kevingandalf.github.io/mpvpn/mpvpn-install)"
```

[![Join our Discord](https://img.shields.io/badge/Discord-Join%20the%20Community-blue?style=for-the-badge)](https://discord.gg/qXRzXvzJQM)


# mpvpn

**mpvpn** ist ein flexibles, modulares System zur dynamischen Verwaltung und Nutzung mehrerer VPN-Gateways parallel. Es wurde entwickelt, um Datenschutz, Ausfallsicherheit und Routing-Kontrolle auf ein neues Level zu bringen – ideal für Umgebungen die den Einsatz verschiedener VPN Anbieter benötigen.

Funktionen im Überblick:
- Multipath-Routing: Nutzt mehrere VPN-Verbindungen gleichzeitig über iproute2, mit automatischem Failover und dynamischer Gewichtung.
- Loadbalancing des gesamten Traffics über alle VPN Verbindungen
- VPN-Gateway-Überwachung: Permanente Prüfung der Verbindungen via ICMP (Ping), automatische Deaktivierung fehlerhafter Pfade aus der Routingtabelle.
- Killswitch-Integration: Aktiviert iptables-Regeln, um bei VPN-Ausfall jeglichen Traffic zu blockieren – schützt zuverlässig vor Datenlecks.
- Split-DNS
- Integration Unbound
- Integration DNSCrypt
- Socks5 over SSH
- Bei Bedarf OpenPGP für Backups

UPCOMING:
- Stealthmode: Schützt deine Privatsspähre auch in Fällen von direkter Kompromittierung - keine Nachvollziehbaren Daten ohne Zugriff auf den LUKS Container.
  - Ablage der gesamten Configs in einem verschlüsselten LUKS Container
  - Manuelles Mouting zum Start von MPVPN notwendig
  - Automatischer Unmount nachdem alle notwendigen Scripte ausgeführt und Verbindungen initiiert worden sind
  - Deaktivierung aller relevanten Systembefehle wie ip route, iptables etc. nach der Aktivierung des Stealthmodes
  - Systemweites Logging wird deaktiviert
    
    [https://github.com/KevinGandalf/mpvpn-mod-stealth](https://github.com/KevinGandalf/mpvpn-mod-stealth)

- Streaming-Modus: Selektives Routing basierend auf Ziel-ASNs oder Diensten (z. B. Netflix, Gaming), gesteuert über konfigurierbare Regeln.
  - DAITA-Kompatibilität: Routing einzelner Domains oder Dienste gezielt über bestimmte VPNs – automatisch und lernfähig.
    [https://github.com/KevinGandalf/mpvpn/tree/testing/beta](https://github.com/KevinGandalf/mpvpn/tree/testing/beta)

## Anforderungen

Alle Variablen werden in der `globals.sh` definiert. Die Anforderungen sind in der `requirements.sh` definiert – dieses Script muss einmalig ausgeführt werden.

Es installiert folgende Pakete:
- curl
- wget
- net-tools
- wireguard
- Bei Bedarf auch OpenVPN
- Bei Bedarf Unbound
- Bei Bedarf DNSCrypt

Alle relevanten Start-Skripte befinden sich im Verzeichnis `/opt/mpvpn/helperscripts/startup`.

## Installation
1. Ein paar dinge vorab erledigen und klonen des Repository:
Das Script führt komfortabel durch den gesamten Installationsprozes. Im Anschluss ist es möglich Wireguard und OpenVPN Konfiguration per Drag&Drop hinzuzufügen.

```bash
#Ubuntu / Debian
sudo apt install wget && sudo bash -c "$(wget -qO- https://kevingandalf.github.io/mpvpn/mpvpn-install)"

#Almalinux, RHEL, Rocky, CentOS etc.
dnf install -y wget && sudo bash -c "$(wget -qO- https://kevingandalf.github.io/mpvpn/mpvpn-install)"
```
oder

```bash
sudo apt update && sudo apt upgrade -y && sudo apt install -y sudo git curl wget
cd /opt
#Root Passwort festlegen
sudo passwd
su
git clone https://github.com/KevinGandalf/mpvpn
```

2. Mache das Script ausführbar:
    ```bash
    cd /opt/mpvpn
    find /opt/mpvpn -type f -name "*.sh" -exec chmod +x {} \;
    ln -s /opt/mpvpn/helperscripts/assets/menu.sh /usr/local/bin/mpvpn
    mpvpn --install
    ```

3. Die Basis-Konfigurationen befinden sich in der Datei `globals.sh`. Die Konfiguration der zu verwendenden VPN-Verbindungen und Routing-Tabellen erfolgt hier.

4. Wireguard (und ggf. OpenVPN Verbindung) Verbindung per Drag&Drop hinzufügen(z.B. per Putty!):
    ```bash
    mpvpn --addwg
    #für OpenVPN
    mpvpn --addovpn
    ```
5. Sysctl vorbereiten
    ```bash
    net.ipv4.ip_forward = 1
    net.ipv6.conf.all.forwarding = 0
    net.ipv6.conf.all.disable_ipv6 = 1
    net.ipv6.conf.default.disable_ipv6 = 1
    net.ipv6.conf.lo.disable_ipv6 = 1
    
    net.ipv4.fib_multipath_hash_policy = 1
    net.ipv4.fib_multipath_use_neigh = 1
    net.ipv4.fib_multipath_hash_fields=0x0037
    net.ipv4.conf.all.rp_filter=2
    net.ipv4.conf.default.rp_filter=2
    net.ipv4.tcp_keepalive_time=300
    net.ipv4.tcp_keepalive_probes=3
    net.ipv4.tcp_keepalive_intvl=30
    net.ipv4.neigh.default.gc_thresh1=1024
    net.ipv4.neigh.default.gc_thresh2=2048
    net.ipv4.neigh.default.gc_thresh3=4096
    net.ipv4.xfrm4_gc_thresh=32768
    
    net.core.rmem_max = 16777216
    net.core.wmem_max = 16777216
    net.ipv4.tcp_rmem = 4096 87380 4194304
    net.ipv4.tcp_wmem = 4096 65536 4194304
    net.ipv4.tcp_window_scaling = 1
    
    net.netfilter.nf_conntrack_max = 524288
    net.netfilter.nf_conntrack_buckets = 131072
    
    net.netfilter.nf_conntrack_tcp_timeout_established = 86400
    net.netfilter.nf_conntrack_tcp_timeout_close = 10
    net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
    net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
    net.netfilter.nf_conntrack_tcp_timeout_last_ack = 30
    net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 60
    net.netfilter.nf_conntrack_tcp_timeout_syn_sent = 120
    net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
    
    net.netfilter.nf_conntrack_udp_timeout = 60
    net.netfilter.nf_conntrack_udp_timeout_stream = 180
    
    net.netfilter.nf_conntrack_icmp_timeout = 30
    
    net.netfilter.nf_conntrack_generic_timeout = 600
    
    fs.file-max = 2097152
    net.core.netdev_max_backlog = 300000
    net.core.somaxconn = 32768
    
    net.ipv4.tcp_reordering = 10
    net.ipv4.tcp_mtu_probing = 1
    ```
## Konfiguration

Der Übersicht halber wurde das Main Script `mpvpn.sh` aufgeräumt und die Sequenzen in einzelne Scripte verpackt. Es gibt mehrere Variablen, die angepasst werden müssen:

### Folgende Variablen müssen ggf. angepasst werden:

```bash
# Basisverzeichnis für VPN-Skripte
BASE_PATH="/opt/mpvpn"

#Standard LAN Interface
DEFAULT_LANIF="enp1s0" 
DEFAULT_LANIP="192.168.1.254"
#Standard Gateway
DEFAULT_WANGW="192.168.1.1"
DEFAULT_SUBNET="192.168.1.0/24"

#Freizugebende Ports 
 PORTS_TCP="22,53,80,443"
 # Zum Beispiel wenn Unbound genutzt wird
 PORTS_UDP="53"

#2Faktor Authentifierung für SSH
#Zum aktivieren ENABLE_SSH2FA=true
ENABLE_SSH2FA=false

WG_CONF_DIR="/etc/wireguard"
OVPN_CONF_DIR="/etc/openvpn"

# WireGuard Konfigurationsnamen (entsprechen den .conf-Dateien in /etc/wireguard)
# Array mit allen VPN-Konfigurationen
WGVPN_LIST=("mullvad1" "mullvad2" "azirevpn1" "azirevpn2" "ivpn1" "ivpn2" "pia" "nordvpn" "surfshark")
#Beispiel:
#WGVPN_LIST=("mullvad" "ovpn" "azirevpn" "surfshark")

# OpenVPN Konfigurationen
ENABLE_OVPN=false
#Default: ENABLE_OVPN=false
#OVPN_LIST=("surfsharkovpn" "nordovpn")

# Wireguard DNS Verbindung je VPN
DNS_AZIREVPN="10.0.0.1,91.231.153.2"		# azirevpn
DNS_MULLVAD="100.64.0.7"      			# mullvad
DNS_IVPN="10.0.254.24,10.0.254.10"		# ivpn
DNS_PIA="10.0.0.241,10.0.0.243"      		# pia
DNS_NORDVPN="103.86.96.100,103.86.99.100"	# nordvpn
DNS_SURFSHARK="162.252.172.57,149.154.159.92"	# surfshark

# Poor-Mans-VPN via ssh
 ENABLE_sSSH=false
 SSH_CMD_OPTIONS="-q -C -N"
 SSH_RELAY_LIST=(
     "ziel1.example.com"
     "ziel2.example.com"
     "ziel3.example.com"
 )
 SSH_RELAY_EXTERNAL_PORTS=(
     "1337"
     "1337"
 )
 SSH_RELAY_LOCAL_PORTS=(
     "2225"
     "3333"
 )
 SSH_CMD_OPTIONS="-q -C -N"
 SSH_PRIVATE_KEY_PATH="/root/.ssh/id_rsa"
 )
 
 #Unbound DNS
 # Um DNS Leaks zu vermeiden sollten immer
 # DNS Server der VPN Dienste genutzt werden!
 ENABLE_UNBOUND=false
 UNBOUND_AUTOSTART=false
 SET_UNBOUND_DNS=(
 "forward-zone:"
  " name: ".""
   "forward-addr: 1.1.1.1"      # cloudflare
   "forward-addr: 8.8.8.8"      # google
   "forward-addr: 100.64.0.7"   # mullvad
   "forward-addr: 10.0.254.24"  # ivpn
 )

 ENABLE_DNSCRYPT=false
 ENABLE_DNSCRYPTPROXY=false
 DNSCRYPT_AUTOSTART=false
 DNSCRYPT_SERVER_NAMES=("dnscrypt.eu-nl" "dnscrypt.eu-dk" "serbica")
 DNSCRYPT_REQUIRE_DNSSEC=true
 DNSCRYPT_REQUIRE_NOLOG=true
 DNSCRYPT_REQUIRE_NOFILTER=true

declare -a EXTRA_RT_TABLES=(
    "100 clear"
    "200 smtp"
    "300 mirror"
    "400 streaming"
)

# Clients die das VPN Routing umgehen
# Auskommentieren, wenn nicht genutzt!
NON_VPN_CLIENTS=(
    "192.168.1.167"
    "192.168.1.164"
    "192.168.1.51"
    "192.168.1.61"
)

ENABLE_Backup=false  # Setze auf true, um das Backup zu aktivieren, false um es zu deaktivieren
 # Backup-Verzeichnis
 BACKUP_DIR="/opt/mpvpn/backups"  # Ordner, in dem Backups gespeichert werden
 # Pfad zum privaten GPG-Schlüssel
 SECRET_KEY="/opt/mpvpn/private.key"  # Pfad zum privaten GPG-Schlüssel
 # Verzeichnisse, die gesichert werden sollen
 SOURCE_DIRS="/opt/mpvpn /etc/wireguard /etc/openvpn"
 # Verzeichnis für die Wiederherstellung
 RESTORE_DIR="/opt/mpvpn/restore"
...
```    
5. MPVPN starten:
    ```bash
    mpvpn --startmpvpn
    ```

## mpvpn Befehle
```bash
    Verfügbare Optionen für mpvpn:
      --startmpvpn   : Startet MPVPN
      --install      : Installiert die Abhängigkeiten
      --addwg        : Neue WireGuard-Verbindung hinzufügen
      --addovpn      : Neue OpenVPN-Verbindung hinzufügen.
      --addsshsocks5 : Socks5 over SSH Verbindung hinzufügen
      --status       : IP Rules Status, Iptables etc.
      --list         : Alle Verbindungen anzeigen.
      --backup       : Erstellt ein Backup
      --restore      : Wiederherstellung eines Backups
      --help         : Zeigt diese Hilfe an.
      --version      : Gibt die Version des Skripts aus.
```

