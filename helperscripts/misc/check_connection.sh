#!/bin/bash

# Log-Datei definieren
LOG_FILE="/var/log/vpn_ip_log.txt"

# Schnittstellen für WireGuard und OpenVPN
wireguard_interfaces=("vpn1" "vpn2" "vpn3" "vpn4")
openvpn_interfaces=("tun0" "tun1")

# Alle Interfaces zusammenführen
all_interfaces=("${wireguard_interfaces[@]}" "${openvpn_interfaces[@]}")

# Aktuelles Datum und Uhrzeit
timestamp=$(date "+%Y-%m-%d %H:%M:%S")

# Status-Variable, ob mindestens ein WireGuard-Interface eine IP hat
wg_has_ip=0

# Loggen der IPs für alle Interfaces
for interface in "${all_interfaces[@]}"; do
  if ip link show "$interface" 2>/dev/null | grep -q "UP"; then
    ip=$(curl --interface "$interface" -s ipinfo.io | grep -oP '"ip": "\K[^"]+')

    if [[ -n $ip ]]; then
      echo "$timestamp - $interface: $ip" >> "$LOG_FILE"
      # Falls ein WireGuard-Interface eine IP hat, setzen wir die Variable
      if [[ " ${wireguard_interfaces[*]} " =~ " ${interface} " ]]; then
        wg_has_ip=1
      fi
    else
      echo "$timestamp - $interface: Keine IP erhalten" >> "$LOG_FILE"
    fi
  fi
done

# Falls KEIN WireGuard-Interface eine IP hat, prüfe und entferne Routen
if [[ $wg_has_ip -eq 0 ]]; then
  echo "$timestamp - Kein WireGuard-VPN mit IP gefunden, überprüfe Routen..." >> "$LOG_FILE"

  # Liste der zu entfernenden Routen
  routes=(
    "0.0.0.0/1 via 10.100.0.1 dev tun0"
    "128.0.0.0/1 via 10.100.0.1 dev tun0"
    "0.0.0.0/1 via 10.8.8.1 dev tun1"
    "128.0.0.0/1 via 10.8.8.1 dev tun1"
  )

  # Durchgehen der Routen und ggf. löschen
  for route in "${routes[@]}"; do
    if ip route show | grep -q "$route"; then
      sudo ip route del $route
      echo "$timestamp - Route entfernt: $route" >> "$LOG_FILE"
    fi
  done
fi
