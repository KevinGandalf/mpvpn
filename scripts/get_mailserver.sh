#!/bin/bash

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

# Netzwerkschnittstelle & Gateway für Routing
INTERFACE="enp1s0"
GATEWAY="192.168.10.1"
TABLE="smtproute"

# Prüfen, ob die Routing-Tabelle existiert, dann leeren
if ip rule list | grep -q "$TABLE"; then
  echo "Flushing routing table $TABLE..."
  ip route flush table $TABLE
else
  echo "Routing table $TABLE does not exist, creating it..."
fi

# ProtonMail & Tutanota Hinweis
echo "ℹ️  ProtonMail benötigt Proton Bridge (lokaler SMTP: 127.0.0.1:1025, IMAP: 127.0.0.1:1143)"
echo "ℹ️  Tutanota unterstützt kein externes SMTP/IMAP-Zugriff, daher keine Routen."

# DNS-Abfragen & Routen setzen
for SERVER in "${MAIL_SERVERS[@]}"; do
  echo "Resolving $SERVER..."
  
  # Nur IPv4-Adressen sammeln, keine CNAMEs
  IPS=$(dig +short A $SERVER | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$")
  
  if [[ -z "$IPS" ]]; then
    echo "⚠️  No IPv4 addresses found for $SERVER, skipping..."
    continue
  fi

  for IP in $IPS; do
    echo "➕ Adding IPv4 route for $IP via $GATEWAY ($INTERFACE)"
    ip route add "$IP" via "$GATEWAY" dev "$INTERFACE" table "$TABLE"
  done
done

ip route add default via $GATEWAY dev $INTERFACE table 200
ip rule add fwmark 200 table 200
ip rule add from all lookup main
ip rule add ipproto tcp dport 25 table smtproute
ip rule add ipproto tcp dport 465 table smtproute
ip rule add ipproto tcp dport 587 table smtproute

echo "✅ Routing updates completed."
