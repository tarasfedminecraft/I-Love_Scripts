#!/bin/bash
set -e

# Визначаємо шлях до папок
INSTALL_DIR="$HOME/Prism_Launcher"
REPO_DIR="PrismLauncher"

echo "--- 1. Встановлення залежностей (Java 17 та 21) ---"
if command -v pacman >/dev/null 2>&1; then
    echo "Виявлено Arch/CachyOS..."
    sudo pacman -S --needed --noconfirm base-devel cmake extra-cmake-modules qt6-base qt6-svg qt6-5compat qt6-declarative qt6-networkauth libsecret glu libarchive qrencode cmark tomlplusplus git perl ninja gamemode vulkan-headers jdk17-openjdk jdk21-openjdk
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
elif command -v dnf >/dev/null 2>&1; then
    echo "Виявлено Fedora..."
    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y cmake extra-cmake-modules qt6-qtbase-devel qt6-qtsvg-devel qt6-qt5compat-devel qt6-qtdeclarative-devel qt6-qtnetworkauth-devel libsecret-devel mesa-libGLU-devel zlib-devel libarchive-devel qrencode-devel cmark-devel tomlplusplus-devel git perl ninja-build gamemode-devel vulkan-headers java-17-openjdk-devel java-21-openjdk-devel
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
elif command -v apt >/dev/null 2>&1; then
    echo "Виявлено Ubuntu/Debian..."
    sudo apt update
    sudo apt install -y build-essential cmake extra-cmake-modules qt6-base-dev qt6-svg-dev qt6-5compat-dev qt6-declarative-dev libqt6core5compat6-dev libqt6networkauth6-dev libsecret-1-dev libglu1-mesa-dev zlib1g-dev libarchive-dev libqrencode-dev libcmark-dev libtomlplusplus-dev git perl ninja-build libgamemode-dev openjdk-17-jdk openjdk-21-jdk
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
fi

export PATH=$JAVA_HOME/bin:$PATH

echo "--- 2. Клонування або оновлення репозиторію ---"
if [ ! -d "$REPO_DIR" ]; then
    git clone --recursive https://github.com/PrismLauncher/PrismLauncher.git "$REPO_DIR"
    cd "$REPO_DIR"
else
    cd "$REPO_DIR"
    git pull
    git submodule update --init --recursive
fi

echo "--- 3. Патчинг коду (Offline Mode / Crack) ---"
# Патчимо MinecraftAccount.h
sed -i 's/return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft;/return true;/' launcher/minecraft/auth/MinecraftAccount.h
# Патчимо AccountList.cpp (використовуємо більш гнучкий пошук)
perl -0777 -i -pe 's/for \(auto account : m_accounts\) \{.*?if \(account->ownsMinecraft\(\)\) \{.*?return true;.*?\}.*?\}/return true;/sg' launcher/minecraft/auth/AccountList.cpp
echo "Код успішно модифіковано."

echo "--- 4. Налаштування збірки (CMake + Ninja) ---"
rm -rf build && mkdir -p build && cd build
cmake .. -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLauncher_QT_VERSION_MAJOR=6 \
    -DCMAKE_INSTALL_PREFIX="../dist" \
    -DCMAKE_Java_COMPILER="$JAVA_HOME/bin/javac"

echo "--- 5. Компіляція (використовуємо всі ядра процесора) ---"
cmake --build . -j$(nproc)
cmake --install .

echo "--- 6. Налаштування Portable версії у $INSTALL_DIR ---"
cd ..
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r dist/* "$INSTALL_DIR/"

# Робимо версію портативною
LAUNCHER_EXEC="$INSTALL_DIR/bin/prismlauncher"
touch "$INSTALL_DIR/bin/portable.txt"
chmod +x "$LAUNCHER_EXEC"

# Створюємо аліас (симлінк)
sudo ln -sf "$LAUNCHER_EXEC" /usr/local/bin/prism

# Створюємо .desktop файл для меню додатків
mkdir -p ~/.local/share/applications
cat <<EOF > ~/.local/share/applications/prism-portable.desktop
[Desktop Entry]
Name=Prism Portable
Comment=Minecraft Launcher (Cracked/Offline)
Exec=$LAUNCHER_EXEC
Icon=prismlauncher
Terminal=false
Type=Application
Categories=Game;
EOF

echo "-------------------------------------------------------"
echo "ГОТОВО! Лаунчер встановлено: $INSTALL_DIR"
echo "Тепер це ідеальна Portable-версія."
echo "Запустити можна командою: prism"
echo "Або знайди 'Prism Portable' у меню програм."
echo "-------------------------------------------------------"

# Запускаємо!
"$LAUNCHER_EXEC" &
