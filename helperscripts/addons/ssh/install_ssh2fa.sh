#!/bin/bash

set -e

# === Konfiguration laden ===
if [[ ! -f /opt/mpvpn/globals.sh ]]; then
  echo "globals.sh nicht gefunden. Bitte sicherstellen, dass sie im gleichen Verzeichnis liegt."
  exit 1
fi

source $BASE_PATH/globals.conf

# === Prüfen ob 2FA aktiviert werden soll ===
if [[ "$ENABLE_SSH2FA" != "true" ]]; then
  echo "[*] SSH 2FA ist in globals.sh deaktiviert. Breche ab."
  exit 0
fi

# === Root-Rechte prüfen ===
if [[ "$EUID" -ne 0 ]]; then
  echo "Bitte führe dieses Skript als root aus."
  exit 1
fi

# === OS erkennen ===
detect_os() {
  if [[ -e /etc/os-release ]]; then
    . /etc/os-release
    OS="${ID,,}"
    VERSION_ID="${VERSION_ID}"
  else
    echo "Betriebssystem konnte nicht erkannt werden (fehlende /etc/os-release)."
    exit 1
  fi

  case "$OS" in
    debian|ubuntu|raspbian|centos|rhel|rocky|almalinux)
      echo "[*] Erkanntes OS: $OS $VERSION_ID"
      ;;
    *)
      echo "Nicht unterstütztes Betriebssystem: $OS"
      exit 1
      ;;
  esac
}

# === Pakete installieren ===
install_packages() {
  echo "[*] Installiere benötigte Pakete..."
  case "$OS" in
    debian|ubuntu|raspbian)
      apt-get update
      apt-get install -y libpam-google-authenticator qrencode oathtool
      ;;
    centos|rhel|almalinux|rocky)
      dnf install -y epel-release || yum install -y epel-release
      dnf install -y google-authenticator qrencode oathtool || yum install -y google-authenticator qrencode oathtool
      ;;
  esac
}

# === PAM & SSHD konfigurieren ===
configure_ssh_pam() {
  PAM_FILE="/etc/pam.d/sshd"
  SSHD_CONFIG="/etc/ssh/sshd_config"

  if ! grep -q "pam_google_authenticator.so" "$PAM_FILE"; then
    echo "auth required pam_google_authenticator.so nullok" >> "$PAM_FILE"
  fi

  sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' "$SSHD_CONFIG"
  sed -i 's/^#\?UsePAM.*/UsePAM yes/' "$SSHD_CONFIG"
}

# === SSH-Dienst neu starten ===
restart_sshd() {
  echo "[*] Starte SSH neu..."
  if systemctl list-units --type=service | grep -q sshd.service; then
    systemctl restart sshd
  else
    systemctl restart ssh
  fi
}

# === TOTP App Setup ===
setup_totp_interactive() {
  echo
  echo "=== SSH 2FA Einrichtung ==="
  echo "Bitte wähle deine bevorzugte TOTP App:"
  echo "1) Google Authenticator (automatische Integration)"
  echo "2) Andere TOTP App (Aegis, FreeOTP, etc. – manuelle Einrichtung)"
  read -rp "Deine Auswahl [1-2]: " choice

  case "$choice" in
    1)
      echo "[*] Starte Google Authenticator für Benutzer: $SUDO_USER"
      su - "$SUDO_USER" -c "google-authenticator"
      ;;
    2)
      SECRET=$(head -c 20 /dev/urandom | base32)
      URI="otpauth://totp/SSH:$(hostname)?secret=$SECRET&issuer=SSH-Server"
      echo
      echo "Geheimer Schlüssel (manuelle Eingabe möglich): $SECRET"
      echo
      echo "$URI" | qrencode -t ANSIUTF8
      echo "[*] Scanne den QR-Code mit deiner TOTP App."
      ;;
    *)
      echo "Ungültige Auswahl. Abbruch."
      exit 1
      ;;
  esac
}

# === Hauptprogramm ===
detect_os
install_packages
configure_ssh_pam
restart_sshd
setup_totp_interactive

echo
echo "[*] SSH 2FA Einrichtung abgeschlossen."
