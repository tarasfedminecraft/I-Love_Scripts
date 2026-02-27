#!/bin/bash

# Перериваємо виконання при будь-якій помилці
set -e

echo "🔍 Визначаємо дистрибутив та встановлюємо залежності..."

# 1. Встановлення залежностей
if [ -f /etc/arch-release ]; then
    echo "📦 Система: Arch Linux / CachyOS. Оновлення..."
    # Виправлено: qt6-networkauth (без s), додано qrencode та інші залежності з твого CMake
    sudo pacman -S --needed --noconfirm base-devel cmake ninja extra-cmake-modules \
    qt6-base qt6-svg qt6-5compat qt6-networkauth jdk17-openjdk libgl \
    cmark libarchive tomlplusplus gamemode qrencode git
elif [ -f /etc/fedora-release ]; then
    echo "📦 Система: Fedora. Оновлення..."
    sudo dnf install -y git extra-cmake-modules make gcc-c++ ninja-build \
    qt6-qtbase-devel qt6-qtsvg-devel qt6-qt5compat-devel qt6-qtnetworkauth-devel \
    zlib-devel mesa-libGL-devel java-17-openjdk-devel cmark-devel libarchive-devel \
    tomlplusplus-devel gamemode-devel qrencode-devel
elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
    echo "📦 Система: Ubuntu/Debian. Оновлення..."
    sudo apt update
    sudo apt install -y git build-essential cmake ninja-build qt6-base-dev qt6-svg-dev \
    qt6-5compat-dev qt6-networkauth-dev zlib1g-dev libgl-dev openjdk-17-jdk \
    extra-cmake-modules libcmark-dev libarchive-dev libtomlplusplus-dev \
    libgamemode-dev libqrencode-dev
else
    echo "⚠️ Невідомий дистрибутив. Спробуйте встановити залежності для Qt6.4+ та CMake вручну."
fi

# 2. Підготовка папки
BUILD_DIR="$HOME/PrismLauncher_Build"
rm -rf "$BUILD_DIR"
echo "📥 Клонування PrismLauncher..."
git clone --recursive https://github.com/PrismLauncher/PrismLauncher.git "$BUILD_DIR"
cd "$BUILD_DIR"

# 3. ПАТЧИНГ (Offline + Java Fix)
echo "🛠️ Застосовуємо патчі до коду..."

# Виправлення сумісності Java (щоб не було помилки 'Source option 7 is no longer supported')
# Ми автоматично міняємо target 7 на 8 у всіх CMakeLists підмодулів Java
echo "☕ Виправляємо версію Java в білд-файлах..."
find libraries/javacheck libraries/launcher -name "CMakeLists.txt" -exec sed -i 's/source 7/source 8/g' {} +
find libraries/javacheck libraries/launcher -name "CMakeLists.txt" -exec sed -i 's/target 7/target 8/g' {} +

# Основний патч для зламу офлайн-режиму
echo "🔓 Розблокування облікових записів..."
perl -0777 -pi -e 's/for\s*\(auto\s*account\s*:\s*m_accounts\)\s*\{\s*if\s*\(account->ownsMinecraft\(\)\)\s*\{\s*return\s*true;\s*\}\s*\}/return true;/g' launcher/minecraft/auth/AccountList.cpp
sed -i 's/bool ownsMinecraft() const { return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft; }/bool ownsMinecraft() const { return true; }/g' launcher/minecraft/auth/MinecraftAccount.h

echo "✅ Код модифіковано."

# 4. ЗБІРКА
echo "🏗️ Починаємо компіляцію (використовуємо Ninja)..."
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DLauncher_BUILD_PLATFORM="Linux"
cmake --build build -j$(nproc)

# 5. Створення портативної папки
echo "📂 Створюємо портативну папку в $HOME/Prism_Launcher..."
PORTABLE_DIR="$HOME/Prism_Launcher"
rm -rf "$PORTABLE_DIR"
mkdir -p "$PORTABLE_DIR"

# Копіюємо готовий файл
cp build/launcher/prismlauncher "$PORTABLE_DIR/"
# Файл-маркер для портативного режиму
touch "$PORTABLE_DIR/portable.txt"

# 6. Налаштування аліасу
SHELL_RC="$HOME/.bashrc"
[[ $SHELL == *"zsh"* ]] && SHELL_RC="$HOME/.zshrc"

if ! grep -q "alias prism=" "$SHELL_RC"; then
    echo "🔗 Додаємо аліас 'prism' у $SHELL_RC"
    echo "alias prism='$PORTABLE_DIR/prismlauncher'" >> "$SHELL_RC"
fi

echo "-------------------------------------------------------"
echo "🎉 Готово! Перезавантаж термінал або введи: source $SHELL_RC"
echo "Запускай лаунчер командою: prism"
