#!/bin/bash

# Überprüfe, ob das Skript als Root ausgeführt wird
if [[ $EUID -ne 0 ]]; then
    echo "Dieses Skript muss als Root ausgeführt werden." 
    exit 1
fi

# Lade globale Variablen
source /opt/mpvpn/globals.sh

# Überprüfe, ob Unbound aktiviert werden soll
if [[ "$ENABLE_UNBOUND" != "true" ]]; then
    echo "Unbound ist nicht aktiviert. Abbruch."
    exit 0
fi

# Überprüfe, ob Unbound automatisch starten soll
if [[ "$UNBOUND_AUTOSTART" != "true" ]]; then
    echo "Unbound wird nicht automatisch gestartet. Abbruch."
    # An dieser Stelle nicht abbrechen, sondern nur keine Systemstart-Aktion durchführen
fi

# Installiere Unbound (abhängig von der Distribution)
if [ -f /etc/almalinux-release ]; then
    # AlmaLinux
    echo "Installiere Unbound auf AlmaLinux..."
    dnf install -y epel-release
    dnf install -y unbound
elif [ -f /etc/rocky-release ]; then
    # Rocky Linux
    echo "Installiere Unbound auf Rocky Linux..."
    dnf install -y epel-release
    dnf install -y unbound
elif [ -f /etc/centos-release ]; then
    # CentOS
    echo "Installiere Unbound auf CentOS..."
    dnf install -y epel-release
    dnf install -y unbound
elif [ -f /etc/redhat-release ]; then
    # RHEL
    echo "Installiere Unbound auf RHEL..."
    dnf install -y epel-release
    dnf install -y unbound
elif [ -f /etc/debian_version ] || [ -f /etc/raspbian-release ]; then
    # Debian/Ubuntu/Raspbian
    if [ -f /etc/raspbian-release ]; then
        echo "Raspbian erkannt. Installiere Unbound..."
    else
        echo "Debian oder Ubuntu erkannt. Installiere Unbound..."
    fi
    apt update
    apt install -y unbound
else
    echo "Unbekannte Distribution. Abbruch."
    exit 1
fi

# Konfiguration der Forward-Zonen
echo "Konfiguriere Unbound..."

# Erstelle Forward-Zonen Liste
forward_zones_list=""
for zone in "${SET_UNBOUND_DNS[@]}"; do
    forward_zones_list+="$zone\n"
done

# Erstelle die Unbound-Konfigurationsdatei
unbound_config="/etc/unbound/unbound.conf.d/forward.conf"

echo -e "$forward_zones_list" > "$unbound_config"

# Überprüfe, ob die Konfigurationsdatei erfolgreich erstellt wurde
if [ -f "$unbound_config" ]; then
    echo "Konfiguration erfolgreich gespeichert: $unbound_config"
else
    echo "Fehler: Konfigurationsdatei konnte nicht erstellt werden."
    exit 1
fi

# Überprüfe, ob Unbound gestartet werden soll
if [[ "$UNBOUND_AUTOSTART" == "true" ]]; then
    echo "Starte Unbound..."
    systemctl enable unbound
    systemctl start unbound

    # Überprüfe, ob der Dienst läuft
    if systemctl is-active --quiet unbound; then
        echo "Unbound wurde erfolgreich installiert und läuft."
    else
        echo "Fehler: Unbound konnte nicht gestartet werden."
        exit 1
    fi
else
    echo "Unbound wird nicht automatisch gestartet, da UNBOUND_AUTOSTART=false gesetzt ist."
fi

# Fertigstellung
echo "Installation und Konfiguration von Unbound abgeschlossen."
