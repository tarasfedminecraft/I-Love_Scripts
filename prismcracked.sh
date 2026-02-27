#!/bin/bash
set -e

echo "🚀 Запуск виправленої збірки для Arch/Ubuntu/Fedora..."

# 1. Встановлення залежностей (виправлено назву для Arch)
if [ -f /etc/arch-release ]; then
    echo "📦 Система: Arch Linux. Встановлення..."
    sudo pacman -S --needed --noconfirm base-devel cmake ninja extra-cmake-modules \
    qt6-base qt6-svg qt6-5compat qt6-networkauth jdk17-openjdk zlib libgl \
    cmark libarchive tomlplusplus gamemode qrencode
elif [ -f /etc/fedora-release ]; then
    echo "📦 Система: Fedora. Встановлення..."
    sudo dnf install -y git extra-cmake-modules make gcc-c++ ninja-build \
    qt6-qtbase-devel qt6-qtsvg-devel qt6-qt5compat-devel qt6-qtnetworkauth-devel \
    zlib-devel mesa-libGL-devel java-17-openjdk-devel cmark-devel libarchive-devel \
    tomlplusplus-devel gamemode-devel qrencode-devel
elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
    echo "📦 Система: Ubuntu/Debian. Встановлення..."
    sudo apt update
    sudo apt install -y git build-essential cmake ninja-build qt6-base-dev qt6-svg-dev \
    qt6-5compat-dev qt6-networkauth-dev zlib1g-dev libgl-dev openjdk-17-jdk \
    extra-cmake-modules libcmark-dev libarchive-dev libtomlplusplus-dev \
    libgamemode-dev libqrencode-dev
fi

# 2. Отримання коду
BUILD_DIR="$HOME/PrismLauncher_Build"
rm -rf "$BUILD_DIR"
git clone --recursive https://github.com/PrismLauncher/PrismLauncher.git "$BUILD_DIR"
cd "$BUILD_DIR"

# 3. ПАТЧИНГ (AccountList + Java Fix)
echo "🛠️ Застосування патчів..."

# Патч логіки облікових записів
perl -0777 -pi -e 's/for\s*\(auto\s*account\s*:\s*m_accounts\)\s*\{\s*if\s*\(account->ownsMinecraft\(\)\)\s*\{\s*return\s*true;\s*\}\s*\}/return true;/g' launcher/minecraft/auth/AccountList.cpp
sed -i 's/bool ownsMinecraft() const { return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft; }/bool ownsMinecraft() const { return true; }/g' launcher/minecraft/auth/MinecraftAccount.h

# 🔥 FIX: Піднімаємо версію Java з 7 до 8, щоб JDK 21 не сварився
echo "☕ Виправлення сумісності Java..."
find libraries/javacheck libraries/launcher -name "CMakeLists.txt" -exec sed -i 's/source 7/source 8/g' {} +
find libraries/javacheck libraries/launcher -name "CMakeLists.txt" -exec sed -i 's/target 7/target 8/g' {} +

# 4. ЗБІРКА
echo "🏗️ Компіляція..."
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DLauncher_BUILD_PLATFORM="Linux"
cmake --build build -j$(nproc)

# 5. ПОРТАТИВНА ПАПКА
echo "📂 Створення портативної папки..."
INSTALL_DIR="$HOME/Prism_Launcher"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp build/launcher/prismlauncher "$INSTALL_DIR/"
touch "$INSTALL_DIR/portable.txt"

# 6. АЛІАС
SHELL_RC="$HOME/.bashrc"
[[ $SHELL == *"zsh"* ]] && SHELL_RC="$HOME/.zshrc"
if ! grep -q "alias prism=" "$SHELL_RC"; then
    echo "alias prism='$INSTALL_DIR/prismlauncher'" >> "$SHELL_RC"
fi

echo "✅ Готово! Спробуй виконати: source $SHELL_RC && prism"
