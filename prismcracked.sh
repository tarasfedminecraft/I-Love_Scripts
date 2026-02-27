#!/bin/bash

# Зупиняти скрипт при помилках
set -e

echo "🚀 Починаємо процес підготовки Prism Launcher..."

# 1. Визначення дистрибутива та встановлення залежностей
if [ -f /etc/arch-release ]; then
    echo "📦 Виявлено Arch Linux. Встановлення залежностей через pacman..."
    sudo pacman -S --needed --noconfirm base-devel cmake qt6-base qt6-svg qt6-5compat qt6-networksauth jdk17-openjdk zlib libgl
elif [ -f /etc/fedora-release ]; then
    echo "📦 Виявлено Fedora. Встановлення залежностей через dnf..."
    sudo dnf install -y git extra-cmake-modules make gcc-c++ qt6-qtbase-devel qt6-qtsvg-devel qt6-qt5compat-devel qt6-qtnetworkauth-devel zlib-devel mesa-libGL-devel java-17-openjdk-devel
elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
    echo "📦 Виявлено Ubuntu/Debian. Встановлення залежностей через apt..."
    sudo apt update
    sudo apt install -y git build-essential cmake qt6-base-dev qt6-svg-dev qt6-5compat-dev qt6-networkauth-dev libqt6core6libqt6network6 libqt6gui6 zlib1g-dev libgl-dev openjdk-17-jdk extra-cmake-modules
else
    echo "❌ Дистрибутив не підтримується автоматично. Встановіть залежності (Qt6, CMake, JDK) вручну."
    exit 1
fi

# 2. Клонування репозиторію
BUILD_DIR="$HOME/prism_build_tmp"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "📥 Клонування репозиторію PrismLauncher..."
git clone --recursive https://github.com/PrismLauncher/PrismLauncher.git .

# 3. Патчинг коду
echo "🛠️ Застосування патчів..."

# Патч для AccountList.cpp
# Шукаємо цикл і замінюємо його на return true;
perl -0777 -pi -e 's/for \(auto account : m_accounts\) \{.*?if \(account->ownsMinecraft\(\)\) \{.*?return true;.*?\}.*?\}/return true;/sg' launcher/minecraft/auth/AccountList.cpp

# Патч для MinecraftAccount.h
# Замінюємо логіку перевірки на жорсткий return true;
sed -i 's/bool ownsMinecraft() const { return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft; }/bool ownsMinecraft() const { return true; }/g' launcher/minecraft/auth/MinecraftAccount.h

echo "✅ Код пропатчено."

# 4. Збірка проєкту
echo "🏗️ Починаємо збірку (це може зайняти час)..."
cmake -B build -DCMAKE_BUILD_TYPE=Release -DLauncher_BUILD_PLATFORM=X11
cmake --build build -j$(nproc)

# 5. Створення портативної папки
echo "📂 Налаштування портативної папки в $HOME/Prism_Launcher..."
INSTALL_DIR="$HOME/Prism_Launcher"
mkdir -p "$INSTALL_DIR"

# Копіюємо бінарник та необхідні ресурси
cp build/launcher/prismlauncher "$INSTALL_DIR/"
# Створюємо порожній файл для портативного режиму (якщо лаунчер це підтримує через прапорці)
touch "$INSTALL_DIR/portable.txt"

# 6. Налаштування аліасу
SHELL_RC="$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"

if ! grep -q "alias prism=" "$SHELL_RC"; then
    echo "🔗 Додавання аліасу 'prism' у $SHELL_RC"
    echo "alias prism='$INSTALL_DIR/prismlauncher'" >> "$SHELL_RC"
else
    echo "ℹ️ Аліас 'prism' вже існує."
fi

echo "---"
echo "🎉 Готово! Перезапустіть термінал або виконайте 'source $SHELL_RC'."
echo "Тепер ви можете запустити лаунчер командою: prism"
