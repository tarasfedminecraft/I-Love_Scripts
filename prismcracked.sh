#!/bin/bash

# Зупиняти при помилках
set -e

echo "🔍 Визначаємо систему та встановлюємо залежності..."

if [ -f /etc/arch-release ]; then
    # Arch Linux
    sudo pacman -S --needed --noconfirm git base-devel cmake ninja qt6-base qt6-svg qt6-5compat qt6-networkauth \
    jdk17-openjdk zlib libgl extra-cmake-modules cmark libarchive tomlplusplus gamemode
elif [ -f /etc/fedora-release ]; then
    # Fedora
    sudo dnf install -y git extra-cmake-modules make gcc-c++ ninja-build \
    qt6-qtbase-devel qt6-qtsvg-devel qt6-qt5compat-devel qt6-qtnetworkauth-devel \
    zlib-devel mesa-libGL-devel java-17-openjdk-devel cmark-devel libarchive-devel \
    tomlplusplus-devel gamemode-devel
elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
    # Ubuntu / Debian
    sudo apt update
    sudo apt install -y git build-essential cmake ninja-build qt6-base-dev qt6-svg-dev \
    qt6-5compat-dev qt6-networkauth-dev libqt6core6 libqt6network6 libqt6gui6 \
    zlib1g-dev libgl-dev openjdk-17-jdk extra-cmake-modules libcmark-dev \
    libarchive-dev libtomlplusplus-dev libgamemode-dev
else
    echo "❌ Дистрибутив не розпізнано. Встановіть Qt6.4+, CMake, Ninja, libarchive, toml++, cmark та gamemode самостійно."
    exit 1
fi

# 2. Підготовка папки збірки
BUILD_ROOT="$HOME/prism_build_temp"
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

echo "📥 Клонування репозиторію..."
git clone --recursive https://github.com/PrismLauncher/PrismLauncher.git .

# 3. ПАТЧИНГ КОДУ
echo "🛠️ Застосування патчів..."

# Патч для AccountList.cpp (Видалення циклу перевірки)
# Використовуємо Perl для надійної багаторядкової заміни
perl -0777 -pi -e 's/for\s*\(auto\s*account\s*:\s*m_accounts\)\s*\{\s*if\s*\(account->ownsMinecraft\(\)\)\s*\{\s*return\s*true;\s*\}\s*\}/return true;/g' launcher/minecraft/auth/AccountList.cpp

# Патч для MinecraftAccount.h (Завжди повертати true для власності)
sed -i 's/bool ownsMinecraft() const { return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft; }/bool ownsMinecraft() const { return true; }/g' launcher/minecraft/auth/MinecraftAccount.h

echo "✅ Патчі успішно застосовано."

# 4. ЗБІРКА
echo "🏗️ Конфігурація та компіляція (використовуємо Ninja для швидкості)..."
# Додаємо -DLauncher_BUILD_PLATFORM для коректного відображення в "About"
cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLauncher_BUILD_PLATFORM="Linux (Custom)" \
    -DLauncher_ENABLE_JAVA_DOWNLOADER=ON

cmake --build build -j$(nproc)

# 5. ПОРТАТИВНА ПАПКА
echo "📂 Налаштування портативної папки..."
INSTALL_DIR="$HOME/Prism_Launcher"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Копіюємо бінарний файл та створюємо portable-мітку
cp build/launcher/prismlauncher "$INSTALL_DIR/"
touch "$INSTALL_DIR/portable.txt"

# 6. АЛІАС
SHELL_RC="$HOME/.bashrc"
[[ $SHELL == *"zsh"* ]] && SHELL_RC="$HOME/.zshrc"

if ! grep -q "alias prism=" "$SHELL_RC"; then
    echo "🔗 Додаємо аліас 'prism' у $SHELL_RC"
    echo "alias prism='$INSTALL_DIR/prismlauncher'" >> "$SHELL_RC"
fi

echo "--------------------------------------------------"
echo "🎉 Готово! Перезапустіть термінал або введіть: source $SHELL_RC"
echo "Тепер запуск лаунчера здійснюється командою: prism"
