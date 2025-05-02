#!/bin/bash

# Lade globale Konfiguration
source $BASE_PATH/globals.conf

# Lokales Arbeitsverzeichnis für temporäre Dateien
BACKUP_WORKDIR="$BASE_PATH/helperscripts/backup"

# Verzeichnisse prüfen & ggf. erstellen
[ ! -d "$BACKUP_WORKDIR" ] && mkdir -p "$BACKUP_WORKDIR"
[ ! -d "$BACKUP_DIR" ] && mkdir -p "$BACKUP_DIR"
[ ! -d "$RESTORE_DIR" ] && mkdir -p "$RESTORE_DIR"

# Backup aktiv?
if [ "$ENABLE_Backup" != "true" ]; then
  echo "Backup ist deaktiviert. Abbruch."
  exit 0
fi

# GPG installieren je nach OS
install_openpgp() {
  echo "🔧 Installiere GPG..."

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      alpine)
        apk update && apk add gnupg
        ;;
      raspbian | debian | ubuntu)
        apt-get update && apt-get install -y gnupg
        ;;
      almalinux | rhel | centos)
        dnf install -y gnupg || yum install -y gnupg
        ;;
      *)
        echo "❌ Nicht unterstütztes OS: $ID"
        exit 1
        ;;
    esac
  else
    echo "❌ OS konnte nicht erkannt werden."
    exit 1
  fi
}

# Prüfe GPG
if ! command -v gpg &>/dev/null; then
  install_openpgp
fi

# Privaten Schlüssel importieren, wenn nötig
if [ ! -f "$SECRET_KEY" ]; then
  echo "❌ Privater Schlüssel nicht gefunden: $SECRET_KEY"
  exit 1
fi

# Überprüfen ob Key bereits importiert ist
KEY_FINGERPRINT=$(gpg --with-colons --import-options show-only --import "$SECRET_KEY" 2>/dev/null | awk -F: '/^fpr:/ { print $10; exit }')
if ! gpg --list-secret-keys | grep -q "$KEY_FINGERPRINT"; then
  echo "🔐 Importiere privaten Schlüssel..."
  gpg --batch --import "$SECRET_KEY"
fi

# Letztes verschlüsseltes Backup finden
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.gpg 2>/dev/null | head -n1)

if [ -z "$LATEST_BACKUP" ]; then
  echo "⚠️  Kein verschlüsseltes Backup gefunden in $BACKUP_DIR"
  exit 1
fi

echo "Letztes Backup gefunden: $LATEST_BACKUP"
read -sp "🔐 Bitte gib die Passphrase zum Entschlüsseln ein: " GPG_PASSPHRASE
echo

# Temporäre Datei
DECRYPTED_FILE="$BACKUP_WORKDIR/restore_$(date +%s).tar.gz"

# Entschlüsselung
gpg --batch --yes --passphrase "$GPG_PASSPHRASE" --pinentry-mode loopback \
    --output "$DECRYPTED_FILE" --decrypt "$LATEST_BACKUP"

if [ $? -ne 0 ]; then
  echo "❌ Entschlüsselung fehlgeschlagen. Prüfe Passphrase oder Schlüssel."
  rm -f "$DECRYPTED_FILE"
  exit 1
fi

# Entpacken
echo "📦 Entpacke Backup nach $RESTORE_DIR ..."
tar -xzf "$DECRYPTED_FILE" -C "$RESTORE_DIR"
rm -f "$DECRYPTED_FILE"

echo "✅ Wiederherstellung abgeschlossen: $RESTORE_DIR"
