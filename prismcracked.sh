#!/bin/bash
set -e

# Конфігурація
INSTALL_DIR="$HOME/Prism_Launcher"
REPO_DIR="PrismLauncher"

echo "--- 1. Встановлення залежностей (Arch/CachyOS фокус) ---"
if command -v pacman >/dev/null 2>&1; then
    # Додано нові компоненти, які вимагає свіжий CMakeLists (DBus, Xml, etc.)
    sudo pacman -S --needed --noconfirm base-devel cmake extra-cmake-modules qt6-base qt6-svg qt6-5compat qt6-declarative qt6-networkauth libsecret glu libarchive qrencode cmark tomlplusplus git perl ninja gamemode vulkan-headers jdk21-openjdk
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y cmake extra-cmake-modules qt6-qtbase-devel qt6-qtsvg-devel qt6-qt5compat-devel qt6-qtdeclarative-devel qt6-qtnetworkauth-devel libsecret-devel mesa-libGLU-devel zlib-devel libarchive-devel qrencode-devel cmark-devel tomlplusplus-devel git perl ninja-build gamemode-devel vulkan-headers java-21-openjdk-devel
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
elif command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y build-essential cmake extra-cmake-modules qt6-base-dev qt6-svg-dev qt6-5compat-dev qt6-declarative-dev libqt6core5compat6-dev libqt6networkauth6-dev libsecret-1-dev libglu1-mesa-dev zlib1g-dev libarchive-dev libqrencode-dev libcmark-dev libtomlplusplus-dev git perl ninja-build libgamemode-dev openjdk-21-jdk
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
fi

export PATH=$JAVA_HOME/bin:$PATH

echo "--- 2. Оновлення репозиторію ---"
if [ ! -d "$REPO_DIR" ]; then
    git clone --recursive https://github.com/PrismLauncher/PrismLauncher.git "$REPO_DIR"
    cd "$REPO_DIR"
else
    cd "$REPO_DIR"
    git pull
    git submodule update --init --recursive
fi

echo "--- 3. Патчинг (Offline Mode + Java 21 Fix) ---"
# Crack: вимикаємо перевірку ліцензії
sed -i 's/return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft;/return true;/' launcher/minecraft/auth/MinecraftAccount.h
perl -0777 -i -pe 's/for \(auto account : m_accounts\) \{.*?if \(account->ownsMinecraft\(\)\) \{.*?return true;.*?\}.*?\}/return true;/sg' launcher/minecraft/auth/AccountList.cpp

# Fix: Змінюємо Java 7 на 8 для сумісності з новим JDK
find libraries -name "CMakeLists.txt" -exec sed -i 's/SOURCE 7/SOURCE 8/g' {} +
find libraries -name "CMakeLists.txt" -exec sed -i 's/TARGET 7/TARGET 8/g' {} +
echo "Патчі успішно застосовано."

echo "--- 4. Налаштування збірки через пресети ---"
# Новий Prism Launcher підтримує --preset. Використовуємо пресет 'linux' (або створюємо свій)
rm -rf build
cmake --preset linux \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="../dist" \
    -DLauncher_QT_VERSION_MAJOR=6 \
    -DCMAKE_Java_COMPILER="$JAVA_HOME/bin/javac"

echo "--- 5. Компіляція та інсталяція ---"
cmake --build build -j$(nproc)
cmake --install build

echo "--- 6. Створення Portable-версії ---"
cd ..
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r dist/* "$INSTALL_DIR/"

# Prism Launcher шукає portable.txt в bin поруч з бінарником
LAUNCHER_EXEC="$INSTALL_DIR/bin/prismlauncher"
touch "$INSTALL_DIR/bin/portable.txt"
chmod +x "$LAUNCHER_EXEC"

# Створення симлінку
sudo ln -sf "$LAUNCHER_EXEC" /usr/local/bin/prism

# Створення Desktop-файлу
mkdir -p ~/.local/share/applications
cat <<EOF > ~/.local/share/applications/prism-portable.desktop
[Desktop Entry]
Name=Prism Portable (Cracked)
Comment=Minecraft Launcher
Exec=$LAUNCHER_EXEC
Icon=prismlauncher
Terminal=false
Type=Application
Categories=Game;
EOF

echo "-------------------------------------------------------"
echo "УСПІХ! Лаунчер зібрано за новою схемою CMake."
echo "Запуск: prism"
echo "Шлях: $INSTALL_DIR"
echo "-------------------------------------------------------"
