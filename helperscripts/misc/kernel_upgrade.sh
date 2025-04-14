#!/bin/bash

update_to_kernel6() {
    echo "🔍 Erkenne Distribution..."

    if [ -f /etc/debian_version ]; then
        echo "➡️  Debian/Ubuntu erkannt."
        echo "🛠️  Füge Backports oder Mainline-Kernel-Repo hinzu..."

        apt update
        apt install -y wget gnupg software-properties-common

        if grep -iq "ubuntu" /etc/os-release; then
            echo "📦 Ubuntu: Installiere mainline Kernel Installer..."
            add-apt-repository -y ppa:cappelikan/ppa
            apt update
            apt install -y mainline
            echo "✅ Starte das Tool mit 'mainline' und wähle Kernel 6.x aus."
        else
            echo "⚠️ Für Debian empfiehlt sich ein manuelles Upgrade via backports oder mainline.debian.org."
            echo "Siehe: https://wiki.debian.org/DebianKernel"
        fi

    elif [ -f /etc/fedora-release ]; then
        echo "➡️ Fedora erkannt."
        dnf install -y kernel-core kernel-devel kernel-headers
        dnf upgrade --refresh -y
        echo "✅ Kernel 6.x wurde installiert oder aktualisiert."

    elif [ -f /etc/rocky-release ] || [ -f /etc/almalinux-release ]; then
        echo "➡️ Rocky/AlmaLinux erkannt."
        yum install -y https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm
        yum install -y --enablerepo=elrepo-kernel kernel-ml kernel-ml-devel
        grub2-set-default 0
        echo "✅ Kernel 6.x wurde installiert und als Standard gesetzt."

    elif [ -f /etc/arch-release ]; then
        echo "➡️ Arch Linux erkannt."
        pacman -Syu --noconfirm
        echo "✅ Arch Linux wurde aktualisiert (Kernel 6.x ist Standard)."

    elif grep -qi "opensuse" /etc/os-release; then
        echo "➡️ openSUSE erkannt."
        zypper ar -f https://download.opensuse.org/repositories/Kernel:/stable/standard/ kernel-stable
        zypper refresh
        zypper install --allow-vendor-change -y kernel-default
        grub2-set-default 0
        echo "✅ Kernel 6.x aus Kernel:stable installiert und gesetzt."

    else
        echo "❌ Distribution nicht unterstützt für automatisches Kernel-Upgrade."
        exit 1
    fi

    echo ""
    read -p "🔁 Möchtest du jetzt neu starten, um den neuen Kernel zu aktivieren? (y/n): " do_reboot
    if [[ "$do_reboot" == "y" || "$do_reboot" == "Y" ]]; then
        echo "♻️ Starte System neu..."
        reboot
    else
        echo "ℹ️ Bitte starte dein System später neu, um den neuen Kernel zu verwenden."
    fi
}

update_to_kernel6
