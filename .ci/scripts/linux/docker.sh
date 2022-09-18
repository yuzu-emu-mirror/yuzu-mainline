#!/bin/bash -ex

# SPDX-FileCopyrightText: 2019 yuzu Emulator Project
# SPDX-License-Identifier: GPL-2.0-or-later

# Exit on error, rather than continuing with the rest of the script.
set -e

ccache -s

mkdir build || true && cd build
cmake .. \
      -DBoost_USE_STATIC_LIBS=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_COMPILER=/usr/lib/ccache/g++ \
      -DCMAKE_C_COMPILER=/usr/lib/ccache/gcc \
      -DCMAKE_INSTALL_PREFIX="/usr" \
      -DDISPLAY_VERSION=$1 \
      -DENABLE_COMPATIBILITY_LIST_DOWNLOAD=ON \
      -DENABLE_QT_TRANSLATION=ON \
      -DUSE_DISCORD_PRESENCE=ON \
      -DYUZU_ENABLE_COMPATIBILITY_REPORTING=${ENABLE_COMPATIBILITY_REPORTING:-"OFF"} \
      -DYUZU_USE_BUNDLED_FFMPEG=ON \
      -GNinja

ninja

ccache -s

ctest -VV -C Release

DESTDIR="$PWD/AppDir" ninja install
rm -vf AppDir/usr/bin/yuzu-cmd AppDir/usr/bin/yuzu-tester

# Download tools needed to build an AppImage
wget -nc https://github.com/yuzu-emu/ext-linux-bin/raw/main/appimage/linuxdeploy-x86_64.AppImage
wget -nc https://github.com/yuzu-emu/ext-linux-bin/raw/main/appimage/linuxdeploy-plugin-qt-x86_64.AppImage
wget -nc https://github.com/yuzu-emu/ext-linux-bin/raw/main/appimage/exec-x86_64.so
# TODO: get this accepted into proper repo
wget -nc https://github.com/Docteh/ext-linux-bin/raw/butts/appimage/checkrt-x86_64

# Set executable bit
chmod 755 \
    checkrt-x86_64 \
    exec-x86_64.so \
    linuxdeploy-x86_64.AppImage \
    linuxdeploy-plugin-qt-x86_64.AppImage

# Workaround for https://github.com/AppImage/AppImageKit/issues/828
export APPIMAGE_EXTRACT_AND_RUN=1

# Deploy yuzu's needed dependencies
./linuxdeploy-x86_64.AppImage --appdir AppDir --plugin qt

# Workaround for libQt5MultimediaGstTools indirectly requiring libwayland-client and breaking Vulkan usage on end-user systems
find AppDir -type f -regex '.*libwayland-client\.so.*' -delete -print

# Workaround for building yuzu with GCC 10 but also trying to distribute it to Ubuntu 18.04 et al.
# See https://github.com/darealshinji/AppImageKit-checkrt
mkdir -p AppDir/usr/optional
mkdir -p AppDir/usr/optional/cxx
mkdir -p AppDir/usr/optional/gcc
cp exec-x86_64.so AppDir/usr/optional/exec.so
cp checkrt-x86_64 AppDir/usr/optional/checkrt
cp --dereference /usr/lib/x86_64-linux-gnu/libstdc++.so.6 AppDir/usr/optional/cxx/libstdc++.so.6
cp --dereference /lib/x86_64-linux-gnu/libgcc_s.so.1 AppDir/usr/optional/gcc/libgcc_s.so.1

# Workaround for different distros putting the ca-certificate bundles in different locations
# Location correct for Ubuntu 18.04 (currently used Docker image is based on this
cp --dereference /etc/ssl/certs/ca-certificates.crt AppDir/ca-certificates.pem

# Customized AppRun script executes above workarounds
cp ../dist/AppRun AppDir/AppRun
chmod 755 AppDir/AppRun
