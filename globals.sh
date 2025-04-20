# Basisverzeichnis für VPN-Skripte
BASE_PATH="/opt/mpvpn"

#Standard LAN Interface
DEFAULT_LANIF="enp1s0" 
#DEFAULT_LANIF=eth0

#Standard Subnet
DEFAULT_SUBNET="192.168.1.0/24"

#Standard Gateway (Router)
DEFAULT_WANGW="192.168.1.1"

WG_CONF_DIR="/etc/wireguard"
OVPN_CONF_DIR="/etc/openvpn"

# WireGuard Konfigurationsnamen (entsprechen den .conf-Dateien in /etc/wireguard)
# Array mit allen VPN-Konfigurationen
WGVPN_LIST=("vpn1" "vpn2" "vpn3" "vpn4")
#Beispiel:
#WGVPN_LIST=("mullvad" "ovpn" "azirevpn" "surfshark")

# OpenVPN Konfigurationen
ENABLE_OVPN=false
#Default: ENABLE_OVPN=false, OpenVPN ist deaktiviert.
#ENABLE_OVPN=true, OpenVPN ist aktiviert.
OVPN_LIST=("vpn5" "vpn6")

# Wireguard DNS Verbindung je VPN
# Zuweisung von benuterdefineirten DNS Server je nach Verbindung
DNS_VPN1="10.0.0.1,91.231.153.2"		# azirevpn
DNS_VPN2="100.64.0.7"      			# mullvad
DNS_VPN3="10.0.254.24,10.0.254.10"		# ivpn
DNS_VPN4="10.0.0.241,10.0.0.243"      		# pia
#DNS_NORDVPN="103.86.96.100,103.86.99.100"	# nordvpn
#DNS_SURFSHARK="162.252.172.57,149.154.159.92"	# surfshark


# Extra Routing Tables
EXTRA_RT_TABLES=(
    "100 clear"  # Diese Tabelle geht über den Standardrouter
    "200 smtp"   # Diese Tabelle geht speziell für den Mailverkehr
)

# Clients die das VPN Routing umgehen
# Auskommentieren, wenn nicht genutzt!
#NON_VPN_CLIENTS=(
#    "192.168.1.4"
#    "192.168.1.5"
#)

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

DOMAINS=(
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
)
