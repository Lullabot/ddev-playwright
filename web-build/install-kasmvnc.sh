#!/bin/bash

if [ $(arch) == "aarch64" ]; then
  KASM_ARCH=arm64
else
  KASM_ARCH=amd64
fi;

RELEASE=$(lsb_release --short --codename)

wget https://github.com/kasmtech/KasmVNC/releases/download/v1.3.0/kasmvncserver_${RELEASE}_1.3.0_${KASM_ARCH}.deb
sudo apt-get install -y ./kasmvncserver*.deb
