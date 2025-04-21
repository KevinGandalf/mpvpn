#!/bin/bash

# Lade globale Konfiguration
source /opt/mpvpn/globals.sh

# Funktion zur Installation von OpenPGP (gpg) auf verschiedenen Betriebssystemen
install_openpgp() {
  echo "OpenPGP (gpg) ist nicht installiert. Installiere gpg..."

  # Überprüfen der Distribution und Installation von gpg
  if [ -f /etc/debian_version ]; then
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      if [[ "$ID" == "raspbian" ]]; then
        # Installation für Raspbian
        sudo apt-get update && sudo apt-get install -y gnupg
        echo "OpenPGP (gpg) wurde auf Raspbian erfolgreich installiert."
      elif [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        # Installation für Debian/Ubuntu
        sudo apt-get update && sudo apt-get install -y gnupg
        echo "OpenPGP (gpg) wurde auf Debian/Ubuntu erfolgreich installiert."
      else
        echo "Unbekannte Debian-basierte Distribution. Bitte installiere OpenPGP (gpg) manuell."
        exit 1
      fi
    fi
  elif [ -f /etc/alpine-release ]; then
    # Installation für Alpine Linux
    sudo apk update && sudo apk add gnupg
    echo "OpenPGP (gpg) wurde auf Alpine Linux erfolgreich installiert."
  else
    echo "Unbekannte Linux-Distribution. Bitte installiere OpenPGP (gpg) manuell."
    exit 1
  fi

  # Überprüfen, ob gpg nach der Installation verfügbar ist
  if ! command -v gpg &> /dev/null; then
    echo "Fehler: OpenPGP konnte nicht installiert werden. Abbruch."
    exit 1
  fi
}

# Funktion zum Erstellen eines GPG-Schlüssels, falls der private Schlüssel nicht existiert
create_gpg_key() {
  echo "Kein GPG-Schlüssel gefunden. Erstelle neuen GPG-Schlüssel."

  # Benutzer nach Name und E-Mail fragen
  read -p "Gib deinen Namen für den GPG-Schlüssel ein: " GPG_NAME
  read -p "Gib deine E-Mail-Adresse ein (für den GPG-Schlüssel): " GPG_EMAIL

  # Benutzer nach einer Passphrase fragen
  read -sp "Gib eine Passphrase für den GPG-Schlüssel ein: " GPG_PASSPHRASE
  echo
  read -sp "Bestätige die Passphrase: " GPG_PASSPHRASE_CONFIRM
  echo

  if [ "$GPG_PASSPHRASE" != "$GPG_PASSPHRASE_CONFIRM" ]; then
    echo "Passphrasen stimmen nicht überein. Abbruch."
    exit 1
  fi

  # Schlüssel erstellen (mit einer Schlüssellänge von 4096 Bit für starke Verschlüsselung)
  gpg --batch --gen-key <<EOF
  %no-protection
  Key-Type: 1
  Key-Length: 4096   # Stärkere Verschlüsselung mit 4096 Bit
  Subkey-Type: 1
  Subkey-Length: 4096
  Name-Real: $GPG_NAME
  Name-Email: $GPG_EMAIL
  Expire-Date: 0
  Passphrase: $GPG_PASSPHRASE
  EOF

  # Exportiere den privaten Schlüssel
  echo "Speichere den privaten Schlüssel in $SECRET_KEY..."
  gpg --armor --export-secret-keys --recipient $GPG_EMAIL --output $SECRET_KEY

  # Bestätigen, dass der Schlüssel gespeichert wurde
  echo "Der private GPG-Schlüssel wurde unter $SECRET_KEY gespeichert."
}

# Überprüfen, ob Backups aktiviert sind
if [ "$ENABLE_Backup" != "true" ]; then
  echo "Backup ist deaktiviert. Abbruch."
  exit 0
fi

# Überprüfen, ob OpenPGP installiert ist
if ! command -v gpg &> /dev/null; then
  install_openpgp  # OpenPGP installieren, falls es nicht gefunden wurde
fi

# Überprüfen, ob der private Schlüssel existiert
if [ ! -f "$SECRET_KEY" ]; then
  create_gpg_key
fi

# Sicherstellen, dass das Backup-Verzeichnis existiert
mkdir -p $BACKUP_DIR

# Erstellen des Backups (tar)
echo "Erstelle Backup..."
tar -czf $BACKUP_DIR/$BACKUP_FILE $SOURCE_DIRS

# Backup verschlüsseln
echo "Verschlüssele das Backup..."
gpg --yes --batch --encrypt --recipient $SECRET_KEY --output $BACKUP_DIR/$ENCRYPTED_BACKUP_FILE $BACKUP_DIR/$BACKUP_FILE

# Backup löschen (optional)
echo "Lösche unverschlüsseltes Backup..."
rm $BACKUP_DIR/$BACKUP_FILE

# Fertig
echo "Backup abgeschlossen und verschlüsselt gespeichert: $BACKUP_DIR/$ENCRYPTED_BACKUP_FILE"
