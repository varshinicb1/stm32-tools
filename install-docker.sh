#!/bin/sh
# STM32MP1 Docker Installer Script (for OpenSTLinux Yocto)
# GitHub friendly - Just curl or wget this and run!

set -e

DOCKER_VERSION=25.0.5
ARCH=armhf
DOCKER_URL="https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VERSION}.tgz"

echo "[INFO] Updating environment..."
mkdir -p ~/docker-install && cd ~/docker-install

echo "[INFO] Downloading Docker ${DOCKER_VERSION} for ${ARCH}..."
wget -q ${DOCKER_URL} -O docker.tgz

echo "[INFO] Extracting Docker binaries..."
tar xzvf docker.tgz

echo "[INFO] Installing Docker binaries to /usr/bin..."
sudo cp docker/* /usr/bin/

echo "[INFO] Creating Docker data directory..."
sudo mkdir -p /etc/docker
sudo mkdir -p /var/lib/docker

echo "[INFO] Starting Docker daemon manually..."
sudo dockerd --host=unix:///var/run/docker.sock &
sleep 5

echo "[INFO] Verifying Docker installation..."
docker version && echo "[SUCCESS] Docker installed and running!" || echo "[ERROR] Docker install failed."

# Optional: Cleanup
cd ~ && rm -rf ~/docker-install
