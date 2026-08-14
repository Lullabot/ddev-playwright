#!/bin/bash
#ddev-generated

if [ $(arch) == "aarch64" ]; then
  KASM_ARCH=arm64
else
  KASM_ARCH=amd64
fi;

RELEASE=$(lsb_release --short --codename)

wget https://github.com/kasmtech/KasmVNC/releases/download/v1.4.0/kasmvncserver_${RELEASE}_1.4.0_${KASM_ARCH}.deb

# Refresh the package lists before installing. The caller mounts a BuildKit
# cache over /var/lib/apt, which shadows any lists baked into an earlier image
# layer, and layers are cached independently -- so this script cannot assume
# whatever ran before it left usable lists behind. Installing the local .deb
# still needs them, to resolve its dependencies.
sudo apt-get update
sudo apt-get install -y ./kasmvncserver*.deb
