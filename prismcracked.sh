#!/bin/bash

# Перериваємо виконання при будь-якій помилці
set -e

echo "🔍 Визначаємо дистрибутив..."

# 1. Встановлення залежностей
if [ -f /etc/arch-release ]; then
    echo "📦 Виявлено Arch Linux. Оновлюємо та встановлюємо пакети..."
    sudo pacman -S --needed --noconfirm base-devel cmake qt6-base qt6-svg qt6-5compat qt6-networksauth jdk17-openjdk zlib libgl extra-cmake-modules
elif [ -f /etc/fedora-release ]; then
    echo "📦 Виявлено Fedora. Встановлюємо пакети..."
    sudo dnf install -y git extra-cmake-modules make gcc-c++ qt6-qtbase-devel qt6-qtsvg-devel qt6-qt5compat-devel qt6-qtnetworkauth-devel zlib-devel mesa-libGL-devel java-17-openjdk-devel
elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
    echo "📦 Виявлено Ubuntu/Debian. Встановлюємо пакети..."
    sudo apt update
    sudo apt install -y git build-essential cmake qt6-base-dev qt6-svg-dev qt6-5compat-dev qt6-networkauth-dev libqt6core6 libqt6network6 libqt6gui6 zlib1g-dev libgl-dev openjdk-17-jdk extra-cmake-modules
else
    echo "⚠️ Невідомий дистрибутив. Спробуйте встановити залежності для Qt6 та CMake вручну."
fi

# 2. Робота з сирцями
BUILD_DIR="$HOME/prism_tmp_build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "📥 Клонування PrismLauncher (з субмодулями)..."
git clone --recursive https://github.com/PrismLauncher/PrismLauncher.git .

# 3. ПАТЧИНГ (Найвідповідальніша частина)
echo "🛠️ Застосовуємо патчі до коду..."

# Патч для AccountList.cpp: Видаляємо весь цикл for і замінюємо на return true;
# Використовуємо perl для багаторядкової заміни
perl -0777 -pi -e 's/for\s*\(auto\s*account\s*:\s*m_accounts\)\s*\{\s*if\s*\(account->ownsMinecraft\(\)\)\s*\{\s*return\s*true;\s*\}\s*\}/return true;/g' launcher/minecraft/auth/AccountList.cpp

# Патч для MinecraftAccount.h: Замінюємо логіку на пряме повернення true
sed -i 's/bool ownsMinecraft() const { return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft; }/bool ownsMinecraft() const { return true; }/g' launcher/minecraft/auth/MinecraftAccount.h

echo "✅ Код модифіковано."

# 4. Збірка
echo "🏗️ Починаємо компіляцію (це займе кілька хвилин)..."
cmake -B build -DCMAKE_BUILD_TYPE=Release -DLauncher_BUILD_PLATFORM=X11
cmake --build build -j$(nproc)

# 5. Створення портативної папки
echo "📂 Створюємо портативну папку в $HOME/Prism_Launcher..."
PORTABLE_DIR="$HOME/Prism_Launcher"
rm -rf "$PORTABLE_DIR"
mkdir -p "$PORTABLE_DIR"

# Копіюємо бінарний файл
cp build/launcher/prismlauncher "$PORTABLE_DIR/"
# Створюємо файл, щоб лаунчер працював у портативному режимі
touch "$PORTABLE_DIR/portable.txt"

# 6. Налаштування аліасу
SHELL_RC=""
if [ -n "$($SHELL -c 'echo $ZSH_VERSION')" ]; then
    SHELL_RC="$HOME/.zshrc"
else
    SHELL_RC="$HOME/.bashrc"
fi

if ! grep -q "alias prism=" "$SHELL_RC"; then
    echo "🔗 Додаємо аліас 'prism' у $SHELL_RC"
    echo "alias prism='$PORTABLE_DIR/prismlauncher'" >> "$SHELL_RC"
    echo "💡 Щоб аліас запрацював, введіть: source $SHELL_RC"
fi

# Очищення
cd "$HOME"
# rm -rf "$BUILD_DIR" # Розкоментуй, якщо хочеш видалити вихідний код після збірки

echo "---"
echo "🎉 Все готово! Запускай командою: prism"
