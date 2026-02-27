#!/bin/bash
set -e

# Перевірка параметрів
BUILD_FLATPAK=false
if [[ "$1" == "--flatpak" ]]; then
    BUILD_FLATPAK=true
fi

echo "--- 1. Встановлення системних залежностей ---"
if command -v pacman >/dev/null 2>&1; then
    echo "Виявлено Arch/CachyOS..."
    sudo pacman -S --needed --noconfirm base-devel cmake extra-cmake-modules qt6-base qt6-svg qt6-5compat qt6-declarative qt6-networkauth libsecret glu libarchive qrencode cmark tomlplusplus git perl ninja gamemode vulkan-headers jdk17-openjdk $( [[ "$BUILD_FLATPAK" == true ]] && echo "flatpak-builder" )
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
elif command -v dnf >/dev/null 2>&1; then
    echo "Виявлено Fedora..."
    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y cmake extra-cmake-modules qt6-qtbase-devel qt6-qtsvg-devel qt6-qt5compat-devel qt6-qtdeclarative-devel qt6-qtnetworkauth-devel libsecret-devel mesa-libGLU-devel zlib-devel libarchive-devel qrencode-devel cmark-devel tomlplusplus-devel git perl ninja-build gamemode-devel vulkan-headers java-17-openjdk-devel $( [[ "$BUILD_FLATPAK" == true ]] && echo "flatpak-builder" )
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
elif command -v apt >/dev/null 2>&1; then
    echo "Виявлено Ubuntu/Debian..."
    sudo apt update
    sudo apt install -y build-essential cmake extra-cmake-modules qt6-base-dev qt6-svg-dev qt6-5compat-dev qt6-declarative-dev libqt6core5compat6-dev libqt6networkauth6-dev libsecret-1-dev libglu1-mesa-dev zlib1g-dev libarchive-dev libqrencode-dev libcmark-dev libtomlplusplus-dev git perl ninja-build libgamemode-dev openjdk-17-jdk flatpak-builder
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
fi

export PATH=$JAVA_HOME/bin:$PATH

echo "--- 2. Клонування або оновлення репозиторію ---"
if [ ! -d "PrismLauncher" ]; then
    git clone --recursive https://github.com/PrismLauncher/PrismLauncher.git
    cd PrismLauncher
else
    cd PrismLauncher
    git pull
    git submodule update --init --recursive
fi

echo "--- 3. Патчинг коду (Offline Mode) ---"
if [ -f launcher/minecraft/auth/MinecraftAccount.h ]; then
    sed -i 's/return data.type != AccountType::Offline && data.minecraftEntitlement.ownsMinecraft;/return true;/' launcher/minecraft/auth/MinecraftAccount.h
    perl -0777 -i -pe 's/for \(auto account : m_accounts\) \{.*?if \(account->ownsMinecraft\(\)\) \{.*?return true;.*?\}.*?\}/return true;/sg' launcher/minecraft/auth/AccountList.cpp
    echo "Код успішно модифіковано."
else
    echo "Помилка: Файли не знайдено!"
    exit 1
fi

echo "--- 4. Налаштування збірки (CMake) ---"
rm -rf build && mkdir -p build && cd build
# Вказуємо CMAKE_INSTALL_PREFIX всередині папки збірки, щоб потім зручно скопіювати все разом
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DLauncher_QT_VERSION_MAJOR=6 -DCMAKE_INSTALL_PREFIX="../dist" -DCMAKE_Java_COMPILER="$JAVA_HOME/bin/javac"

echo "--- 5. Компіляція ---"
cmake --build . -j$(nproc)
cmake --install . # Це підготує всі ресурси в папці ../dist

if [ "$BUILD_FLATPAK" = true ]; then
    echo "--- 6. Збірка Flatpak ---"
    cd ..
    cat <<EOF > org.prismlauncher.PrismCracked.yml
app-id: org.prismlauncher.PrismCracked
runtime: org.kde.Platform
runtime-version: '6.6'
sdk: org.kde.Sdk
command: prismlauncher
finish-args:
  - --share=network
  - --share=ipc
  - --socket=x11
  - --socket=wayland
  - --device=dri
  - --filesystem=home
modules:
  - name: prism
    buildsystem: cmake-ninja
    sources:
      - type: dir
        path: .
    build-commands:
      - cmake --build build --target install
EOF
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak-builder --user --install --force-clean build-flatpak org.prismlauncher.PrismCracked.yml
    echo "--- Flatpak встановлено! ---"
else
    echo "--- 6. Встановлення у ~/Prism_Launcher ---"
    INSTALL_DIR="$HOME/Prism_Launcher"
    
    # Видаляємо стару папку, якщо вона була, щоб оновлення було чистим
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    
    # Копіюємо все з папки dist (бінарник, іконки, ліби) у нашу папку в Home
    cp -r ../dist/* "$INSTALL_DIR/"
    
    # Створюємо файл portable.txt, щоб усі дані гри були в цій папці
    touch "$INSTALL_DIR/portable.txt"
    
    # Робимо файл виконуваним (на випадок, якщо права збилися)
    chmod +x "$INSTALL_DIR/prismlauncher"
    
    # Створення аліасу для термінала
    sudo ln -sf "$INSTALL_DIR/prismlauncher" /usr/local/bin/prism
    
    echo "-------------------------------------------------------"
    echo "ГОТОВО! Лаунчер та всі його файли знаходяться у: $INSTALL_DIR"
    echo "Тепер це Portable-версія (моди та світи будуть у цій же папці)."
    echo "Запускай лаунчер командою: prism"
    echo "-------------------------------------------------------"
fi
