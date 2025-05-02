#!/bin/bash

# Lade globale Konfiguration
source $BASE_PATH/globals.conf

# Lokales Arbeitsverzeichnis für Backup-Skripte und temporäre Dateien
BACKUP_WORKDIR="$BASE_PATH/helperscripts/backup"

# Sicherstellen, dass das Verzeichnis existiert
mkdir -p "$BACKUP_WORKDIR"

# Funktion zur Installation von OpenPGP (gpg)
install_openpgp() {
  echo "OpenPGP (gpg) ist nicht installiert. Installiere gpg..."

  if [ -f /etc/debian_version ]; then
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      if [[ "$ID" == "raspbian" ]]; then
        sudo apt-get update && sudo apt-get install -y gnupg
      elif [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        sudo apt-get update && sudo apt-get install -y gnupg
      else
        echo "Unbekannte Debian-basierte Distribution."
        exit 1
      fi
    fi
  elif [ -f /etc/alpine-release ]; then
    sudo apk update && sudo apk add gnupg
  else
    echo "Unbekannte Linux-Distribution."
    exit 1
  fi

  if ! command -v gpg &> /dev/null; then
    echo "OpenPGP konnte nicht installiert werden. Abbruch."
    exit 1
  fi
}

# Funktion zum Erstellen eines GPG-Schlüssels
create_gpg_key() {
  echo "Kein GPG-Schlüssel gefunden. Erstelle neuen GPG-Schlüssel."

  read -p "Gib deinen Namen für den GPG-Schlüssel ein: " GPG_NAME
  read -p "Gib deine E-Mail-Adresse ein (für den GPG-Schlüssel): " GPG_EMAIL

  read -sp "Gib eine Passphrase ein: " GPG_PASSPHRASE
  echo
  read -sp "Bestätige die Passphrase: " GPG_PASSPHRASE_CONFIRM
  echo

  if [ "$GPG_PASSPHRASE" != "$GPG_PASSPHRASE_CONFIRM" ]; then
    echo "Passphrasen stimmen nicht überein."
    exit 1
  fi

  gpg --batch --gen-key <<EOF
  %no-protection
  Key-Type: 1
  Key-Length: 4096
  Subkey-Type: 1
  Subkey-Length: 4096
  Name-Real: $GPG_NAME
  Name-Email: $GPG_EMAIL
  Expire-Date: 0
  Passphrase: $GPG_PASSPHRASE
EOF

  echo "Exportiere privaten Schlüssel nach $SECRET_KEY..."
  gpg --armor --export-secret-keys "$GPG_EMAIL" > "$SECRET_KEY"
}

# Aktivierung prüfen
if [ "$ENABLE_Backup" != "true" ]; then
  echo "Backup deaktiviert."
  exit 0
fi

# gpg prüfen/installieren
if ! command -v gpg &> /dev/null; then
  install_openpgp
fi

# Falls kein Key vorhanden, anlegen
if [ ! -f "$SECRET_KEY" ]; then
  create_gpg_key
fi

# Backup-Verzeichnis aus globals.sh verwenden
mkdir -p "$BACKUP_DIR"

# Backup-Dateinamen definieren
BACKUP_FILE="$BACKUP_WORKDIR/backup_$(date +%F).tar.gz"
ENCRYPTED_BACKUP_FILE="$BACKUP_DIR/backup_$(date +%F).tar.gz.gpg"

# Backup erstellen
echo "Erstelle Backup..."
tar -czf "$BACKUP_FILE" $SOURCE_DIRS

# Backup verschlüsseln
echo "Verschlüssele Backup..."
gpg --yes --batch --encrypt --recipient "$SECRET_KEY" --output "$ENCRYPTED_BACKUP_FILE" "$BACKUP_FILE"

# Unverschlüsseltes entfernen
rm "$BACKUP_FILE"

echo "Backup abgeschlossen: $ENCRYPTED_BACKUP_FILE"
