#!/bin/bash

# Зупинити скрипт у разі помилки
set -e

echo "🚀 Починаємо процес підготовки та збірки Prism Launcher (Release)..."

# 1. Визначення дистрибутива та встановлення залежностей
if [ -f /etc/debian_version ]; then
    echo "📦 Виявлено Debian/Ubuntu-подібний дистрибутив."
    sudo apt update
    sudo apt install -y \
        build-essential \
        cmake ninja-build extra-cmake-modules pkg-config scdoc \
        qt6-base-dev qt6-image-formats-plugins qt6-networkauth-dev qt6-svg-dev \
        cmark gamemode-dev libarchive-dev libcmark-dev libgl1-mesa-dev libqrencode-dev libtomlplusplus-dev zlib1g-dev \
        git openjdk-17-jdk
elif [ -f /etc/arch-release ]; then
    echo "📦 Виявлено Arch Linux."
    sudo pacman -S --needed --noconfirm \
        base-devel cmake ninja extra-cmake-modules pkg-config scdoc \
        qt6-base qt6-imageformats qt6-networkauth qt6-svg \
        cmark gamemode libarchive mesa qrencode tomlplusplus zlib \
        jdk17-openjdk git
elif [ -f /etc/fedora-release ]; then
    echo "📦 Виявлено Fedora."
    sudo dnf install -y \
        gcc-c++ cmake ninja-build extra-cmake-modules pkgconfig scdoc \
        qt6-qtbase-devel qt6-qtimageformats qt6-qtnetworkauth-devel qt6-qtsvg-devel \
        cmark gamemode-devel libarchive-devel libcmark-devel mesa-libGL-devel libqrencode-devel tomlplusplus-devel zlib-devel \
        git java-17-openjdk-devel
else
    echo "❌ Дистрибутив не підтримується автоматично. Встановіть залежності вручну."
    exit 1
fi

# 2. Клонування репозиторію
if [ -d "PrismLauncher" ]; then
    rm -rf PrismLauncher
fi

echo "📥 Клонування репозиторію..."
git clone --recursive https://github.com/PrismLauncher/PrismLauncher.git
cd PrismLauncher

# 3. Модифікація файлів (Патчинг)
echo "🛠️ Застосування патчів до сирців..."
CPP_FILE="launcher/minecraft/auth/AccountList.cpp"
H_FILE="launcher/minecraft/auth/MinecraftAccount.h"

perl -0777 -pi -e 's/for \(auto account : m_accounts\) \{.*?return false;/return true;/sg' "$CPP_FILE"
sed -i 's/bool ownsMinecraft() const { return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft; }/bool ownsMinecraft() const { return true; }/g' "$H_FILE"

# 4. Збірка проекту
echo "🏗️ Налаштування CMake..."
cmake --preset linux -DCMAKE_BUILD_TYPE=Release

# Використовуємо всі ядра
CPU_CORES=$(nproc)
echo "🛠️ Компіляція на $CPU_CORES ядрах (Release)..."
cmake --build build --config Release --parallel $CPU_CORES

# 5. Встановлення
echo "💾 Встановлення в систему..."
sudo cmake --install build --config Release --prefix /usr/local

# 6. Очищення
echo "🧹 Видалення тимчасових файлів збірки..."
cd ..
rm -rf PrismLauncher

echo "🎉 Готово! Prism Launcher встановлено."
echo "Запустити можна командою: prismlauncher"
