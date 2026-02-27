#!/bin/bash
set -e
echo "--- 1. Встановлення залежностей (Arch, Fedora або Ubuntu) ---"
if command -v pacman >/dev/null 2>&1; then
    echo "Виявлено Arch/CachyOS..."
    sudo pacman -S --needed --noconfirm \
        base-devel cmake extra-cmake-modules \
        qt6-base qt6-svg qt6-5compat qt6-declarative \
        qt6-networkauth libsecret glu \
        libarchive qrencode cmark tomlplusplus git perl ninja \
        gamemode vulkan-headers jdk17-openjdk
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
    export PATH=$JAVA_HOME/bin:$PATH
elif command -v dnf >/dev/null 2>&1; then
    echo "Виявлено Fedora..."
    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y cmake extra-cmake-modules \
        qt6-qtbase-devel qt6-qtsvg-devel qt6-qt5compat-devel qt6-qtdeclarative-devel \
        qt6-qtnetworkauth-devel libsecret-devel mesa-libGLU-devel zlib-devel \
        libarchive-devel qrencode-devel cmark-devel tomlplusplus-devel git perl \
        ninja-build gamemode-devel vulkan-headers java-17-openjdk-devel
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
    export PATH=$JAVA_HOME/bin:$PATH
elif command -v apt >/dev/null 2>&1; then
    echo "Виявлено Ubuntu/Debian..."
    sudo apt update
    sudo apt install -y build-essential cmake extra-cmake-modules \
        qt6-base-dev qt6-svg-dev qt6-5compat-dev qt6-declarative-dev \
        libqt6core5compat6-dev libqt6networkauth6-dev \
        libsecret-1-dev libglu1-mesa-dev zlib1g-dev \
        libarchive-dev libqrencode-dev libcmark-dev \
        libtomlplusplus-dev git perl ninja-build libgamemode-dev openjdk-17-jdk
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
    export PATH=$JAVA_HOME/bin:$PATH
fi
echo "--- 2. Клонування або оновлення репозиторію ---"
if [ ! -d "PrismLauncher" ]; then
    git clone --recursive https://github.com/PrismLauncher/PrismLauncher.git
    cd PrismLauncher
else
    cd PrismLauncher
    git pull
    git submodule update --init --recursive
fi
echo "--- 3. Модифікація сирцевого коду (Патч) ---"
if [ -f launcher/minecraft/auth/MinecraftAccount.h ]; then
    sed -i 's/return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft;/return true;/' launcher/minecraft/auth/MinecraftAccount.h
    perl -0777 -i -pe 's/for \(auto account : m_accounts\) \{.*?if \(account->ownsMinecraft\(\)\) \{.*?return true;.*?\}.*?\}/return true;/sg' launcher/minecraft/auth/AccountList.cpp
    echo "Код успішно модифіковано."
else
    echo "Помилка: Файли для патчу не знайдено!"
    exit 1
fi
echo "--- 4. Налаштування збірки (CMake) ---"
rm -rf build && mkdir -p build && cd build
cmake .. \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLauncher_QT_VERSION_MAJOR=6 \
    -DCMAKE_INSTALL_PREFIX="../dist" \
    -DCMAKE_Java_COMPILER="$JAVA_HOME/bin/javac"
echo "--- 5. Компіляція (Ryzen 5) ---"
cmake --build . -j$(nproc)
echo "-------------------------------------------------------"
echo "ГОТОВО! Запускай лаунчер командою:"
echo "$(pwd)/prismlauncher"
echo "-------------------------------------------------------"
