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
    "192.168.10.167"
    "192.168.10.164"
    "192.168.10.51"
    "192.168.10.61"
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

# Mailserver-Hostnamen (erweiterbar)
MAIL_SERVERS=(
  # Google Mail
  "smtp.gmail.com"
  "alt1.smtp.gmail.com"
  "alt2.smtp.gmail.com"
  "alt3.smtp.gmail.com"
  "alt4.smtp.gmail.com"
  "imap.gmail.com"

  # iCloud (Apple)
  "imap.mail.me.com"
  "smtp.mail.me.com"
  "mx01.mail.icloud.com."
  "mx02.mail.icloud.com."

  # GMX
  "imap.gmx.net"
  "mail.gmx.net"

  # Yahoo Mail
  "imap.mail.yahoo.com"
  "smtp.mail.yahoo.com"

  # Outlook / Hotmail / Microsoft
  "imap-mail.outlook.com"
  "smtp-mail.outlook.com"
  "imap.office365.com"
  "smtp.office365.com"
  "imap.exchange.microsoft.com"
  "smtp.exchange.microsoft.com"
  "imap.live.com"
  "smtp.live.com"

  # Zoho Mail
  "imap.zoho.com"
  "smtp.zoho.com"

  # FastMail
  "imap.fastmail.com"
  "smtp.fastmail.com"

  # Anonyme / Datenschutzorientierte Mailanbieter
  "imap.mailfence.com"
  "smtp.mailfence.com"
  "imap.riseup.net"
  "smtp.riseup.net"
  "imap.startmail.com"
  "smtp.startmail.com"
  "imap.countermail.com"
  "smtp.countermail.com"
)

CLEARDOMAINS=(
  "bild.de"
  "netflix.com"
  "amazon.de"
  "amazon.com"
  "paypal.com"
  "bankofamerica.com"
  "sparkasse.de"
  "postbank.de"
  "playstation.com"
  "nintendo.com"
  "steamcommunity.com"
  "epicgames.com"
  "icloud.com"
  "github.com"
  "kicker.de"
  "dkb.de"
  "comdirect.de"
  "ing.de"
  "n26.com"
  "ebay.de"
  "otto.de"
  "zalando.de"
  "rtlplus.de"
  "zdf.de"
  "ard.de"
) 
MIRRORDOMAINS=(
  "repo.almalinux.org"
  "mirror.centos.org"
  "mirrors.edge.kernel.org"
  "vault.centos.org"
  "dl.fedoraproject.org"
  "mirrors.fedoraproject.org"
  "deb.debian.org"
  "security.debian.org"
  "ftp.debian.org"
  "archive.ubuntu.com"
  "security.ubuntu.com"
  "ppa.launchpad.net"
  "mirror.archlinuxarm.org"
  "archlinux.org"
  "mirrors.kernel.org"
  "repo.manjaro.org"
  "download.opensuse.org"
  "mirrorcache.opensuse.org"
  "distfiles.gentoo.org"
  "gentoo.osuosl.org"
  "packagecloud.io"
  "repo.nordvpn.com"
  "mirrors.almalinux.org"
  "mirror.virtarix.com"
  "mirror.junda.nl"
  "app.n26.de"
  "elrepo.org"
  "mirrors.elrepo.org"
  "mirror.selfnet.de"
  "kleinanzeigen.de"
  "ftp.fau.de"
  "mirror.junda.nl"
  "ftp.gwdg.de"
  "almalinux.schlundtech.de"
  "mirror.23m.com"
    "mirror.netzwerge.de"
    "mirror.dogado.de"
  "de.mirrors.clouvider.net"
    "mirror.plusserver.com"
    "mirror.rackspeed.de"
  "ftp.halifax.rwth-aachen.de"
  "almalinux-mirror.bernini.dev"
  "ftp.gwdg.de"
    "mirrors.xtom.de"
    "mirror.virtarix.com"
  "ftp.fau.de"
    "mirror.hs-esslingen.de"
  "ftp.uni-bayreuth.de"
    "mirror.de.leaseweb.net"
  "ptbtime1.ptb.de"
  "ptbtime2.ptb.de"
  "ptbtime3.ptb.de"
  "de.archive.ubuntu.com"
  "ftp.halifax.rwth-aachen.de"
    "mirror.netcologne.de"
    "mirror.hetzner.de"
  "ubuntu.mirror.lrz.de"
    "mirror.dogado.de"
    "mirror.funkfreundelandshut.de"
  "archive.ubuntu.com"
    "mirror.pnl.gov"
    "mirror.math.princeton.edu"
    "mirror.kku.ac.th"
    "mirror.nus.edu.sg"
    "mirror.ox.ac.uk"
  "raspbian.raspberrypi.org"
  "ftp.halifax.rwth-aachen.de"
    "mirror.netcologne.de"
    "mirror1.hs-esslingen.de"
    "mirror.funkfreundelandshut.de"
    "mirror.dogado.de"
    "mirror.digitalpacific.com.au"
    "mirror.datamossa.io"
    "mirror.launtel.net.au"
    "mirror.realcompute.io"
    "mirror.lagoon.nc"
  "ftp.de.debian.org"
  "ftp.halifax.rwth-aachen.de"
   "mirror.netcologne.de"
   "ftp.uni-kl.de"
   "ftp.fau.de"
   "mirror.hetzner.de"
   "deb.debian.org"
   "ftp.debian.org"
   "mirror.yandex.ru"
   "mirror.nus.edu.sg"
   "mirror.ox.ac.uk"
   "mirror.kku.ac.th"
   "mirror.almalinux.org"
   "mirror.hetzner.de"
   "mirror.netcologne.de"
   "mirror.funkfreundelandshut.de"
   "mirror.dogado.de"
   "repo.almalinux.org"
   "mirror.cedia.org.ec"
   "mirror.flokinet.net"
   "mirror.serverfreak.com"
   "mirror.ipserverone.com"
   "mirror.controlvm.com"
   "mirror.gotmyhost.com"
   "mirror.vsys.host"
   "mirror.dk.team.blue"
  "vn-mirrors.vhost.vn"
  "almalinux.mirrors.ovh.net"
  "mirror.ibcp.fr"
  "mirror.netweaver.uk"
"almalinux.mirror.thegigabit.com"
  "mirror.vtti.vt.edu"
  "mirror.iphost.md"
  "mirrors.gbnetwork.com"
  "mirror.sfo12.us.leaseweb.net"
  "mirror.server.net"
  "mirror.rackspeed.de"
  "mirror.ixirhost.com"
"insect.mm.fcix.net"
  "mirror.xenyth.net"
"pkg.adfinis-on-exoscale.ch"
"muug.ca"
"per.aws.repo.almalinux.org"
"kozyatagi.mirror.guzel.net.tr"
  "mirrors.xtom.ee"
  "mirror.ossplanet.net"
"almalinux.mirror.wearetriple.com"
"for.aws.repo.almalinux.org"
  "mirrors.rda.run"
  "mirrors.isu.net.sa"
  "mirrors.tino.org"
  "mirror.raiolanetworks.com"
  "mirror.ekiphost.com"
  "mirror.mx.hawkhost.com"
  "mirror.2degrees.nz"
"phx.mirrors.clouvider.net"
  "mirror.yuki.net.uk"
"capital.hoster.kz"
"bna.aws.repo.almalinux.org"
"ftp.jaist.ac.jp"
  "mirrors.hostico.ro"
"elmirror.cl"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
  "mirror.2degrees.nz"
  "mirror.yuki.net.uk"
  "mirror.ekiphost.com"
  "mirror.raiolanetworks.com"
)
