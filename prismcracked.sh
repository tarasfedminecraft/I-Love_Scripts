#!/bin/bash
set -e

echo "--- 1. Встановлення системних залежностей (Arch/CachyOS) ---"
# Додано jdk21-openjdk, оскільки нові версії MC її вимагають
if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm base-devel cmake extra-cmake-modules qt6-base qt6-svg qt6-5compat qt6-declarative qt6-networkauth libsecret glu libarchive qrencode cmark tomlplusplus git perl ninja gamemode vulkan-headers jdk21-openjdk
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y cmake extra-cmake-modules qt6-qtbase-devel qt6-qtsvg-devel qt6-qt5compat-devel qt6-qtdeclarative-devel qt6-qtnetworkauth-devel libsecret-devel mesa-libGLU-devel zlib-devel libarchive-devel qrencode-devel cmark-devel tomlplusplus-devel git perl ninja-build gamemode-devel vulkan-headers java-21-openjdk-devel
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
elif command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y build-essential cmake extra-cmake-modules qt6-base-dev qt6-svg-dev qt6-5compat-dev qt6-declarative-dev libqt6core5compat6-dev libqt6networkauth6-dev libsecret-1-dev libglu1-mesa-dev zlib1g-dev libarchive-dev libqrencode-dev libcmark-dev libtomlplusplus-dev git perl ninja-build libgamemode-dev openjdk-21-jdk
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
fi

export PATH=$JAVA_HOME/bin:$PATH

echo "--- 2. Клонування або оновлення репозиторію PrismLauncher ---"
if [ ! -d "PrismLauncher" ]; then
    git clone --recursive https://github.com/PrismLauncher/PrismLauncher.git
    cd PrismLauncher
else
    cd PrismLauncher
    git pull
    git submodule update --init --recursive
fi

echo "--- 3. Патчинг для Offline Mode (Crack) ---"
if [ -f launcher/minecraft/auth/MinecraftAccount.h ]; then
    sed -i 's/return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft;/return true;/' launcher/minecraft/auth/MinecraftAccount.h
    perl -0777 -i -pe 's/for \(auto account : m_accounts\) \{.*?if \(account->ownsMinecraft\(\)\) \{.*?return true;.*?\}.*?\}/return true;/sg' launcher/minecraft/auth/AccountList.cpp
    echo "Код успішно модифіковано."
else
    echo "Помилка: Файли для патчингу не знайдено!"
    exit 1
fi

echo "--- 4. Налаштування збірки (CMake) ---"
rm -rf build && mkdir -p build && cd build
cmake .. -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLauncher_QT_VERSION_MAJOR=6 \
    -DCMAKE_INSTALL_PREFIX="../dist" \
    -DCMAKE_Java_COMPILER="$JAVA_HOME/bin/javac"

echo "--- 5. Компіляція (використовуємо всі ядра) ---"
cmake --build . -j$(nproc)
cmake --install . 

echo "--- 6. Налаштування папки Prism_Launcher у Home ---"
INSTALL_DIR="$HOME/Prism_Launcher"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Копіюємо скомпільовані файли
cp -r ../dist/* "$INSTALL_DIR/"

# Шлях до бінарника
LAUNCHER_EXEC="$INSTALL_DIR/bin/prismlauncher"

# Створюємо маркер портативності
touch "$INSTALL_DIR/bin/portable.txt"
chmod +x "$LAUNCHER_EXEC"

# Створення системного симлінку (аліасу)
echo "Створення аліасу 'prism'..."
sudo ln -sf "$LAUNCHER_EXEC" /usr/local/bin/prism

echo "-------------------------------------------------------"
echo "УСПІШНО! Лаунчер встановлено в: $INSTALL_DIR"
echo "Режим: Portable (все зберігається в папці bin)."
echo "Команда для запуску: prism"
echo "-------------------------------------------------------"

# Автоматичний запуск
echo "Запуск лаунчера..."
"$LAUNCHER_EXEC" &
