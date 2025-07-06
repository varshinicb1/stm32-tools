#!/bin/sh
set -e

USER_HOME="/home/varshini"

# --- Part 1: Install Docker ---
echo "🚀 Installing Docker static binaries..."
ARCH=armhf
DOCKER_VER=24.0.6
URL="https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VER}.tgz"
wget -q "$URL" -O /tmp/docker.tgz
tar -xzf /tmp/docker.tgz -C /tmp
sudo cp /tmp/docker/* /usr/bin/

echo "⭐ Ensuring Docker directories & starting daemon..."
sudo mkdir -p /etc/docker /var/lib/docker
if ! pgrep -x dockerd >/dev/null; then
  sudo dockerd --host=unix:///var/run/docker.sock \
    --data-root=/var/lib/docker > /tmp/dockerd.log 2>&1 &
  sleep 5
fi
docker version || { echo "[ERROR] Docker setup failed"; exit 1; }

# --- Part 2: Setup systemd for dockerd auto-start ---
echo "🏁 Enabling Docker auto-start via systemd..."
read -r -d '' SYSTEMD_SERVICE <<EOF
[Unit]
Description=Docker Daemon
After=network.target

[Service]
ExecStart=/usr/bin/dockerd --host=unix:///var/run/docker.sock --data-root=/var/lib/docker
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
echo "$SYSTEMD_SERVICE" | sudo tee /etc/systemd/system/docker.service >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable docker

# --- Part 3: Prepare persistent OpenWRT workspace ---
echo "🗂️ Creating persistent workspace..."
mkdir -p "$USER_HOME/openwrt-work"
sudo chown "$USER_HOME:$USER_HOME" "$USER_HOME/openwrt-work"

# --- Part 4: Deploy OpenWRT container ---
echo "📦 Pulling and Running OpenWRT container..."
docker pull openwrtorg/rootfs
docker rm -f openwrt-dev 2>/dev/null || true
docker run -d --name openwrt-dev --privileged \
  -v "$USER_HOME/openwrt-work:/root/openwrt" \
  --network host openwrtorg/rootfs sleep infinity

echo "🔧 Initializing OpenWRT container..."
docker exec openwrt-dev opkg update
docker exec openwrt-dev opkg install luci uhttpd dropbear
docker exec openwrt-dev /etc/init.d/uhttpd enable
docker exec openwrt-dev /etc/init.d/dropbear enable

# --- Part 5: Setup 4G modem bridging ---
echo "📡 Enabling 4G USB modem passthrough..."
iptables -t nat -A POSTROUTING -o end0 -j MASQUERADE
echo "Echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
echo "✅ 4G USB passthrough ready; just add modem in openwrt"

# --- Part 6: Setup GUI container (Weston + GTK3) ---
echo "🎨 Optional: Running GUI container with Weston support..."
docker rm -f sink-gui 2>/dev/null || true
docker run -d --name sink-gui \
  --network host --privileged \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  --device /dev/dri \
  --device /dev/input/event0 \
  --device /dev/input/event1 \
  ghcr.io/efrantzis/wayland-sink:latest

# --- Cleanup ---
echo "🧼 Cleaning up Docker temp files..."
rm -rf /tmp/docker.tgz /tmp/docker

echo "✅ Setup complete!"
echo "• Dockerd auto-start enabled."
echo "• OpenWRT container ready; enter with: docker exec -it openwrt-dev /bin/sh"
echo "• Access LuCI at http://<stm32-ip>:80"
echo "• 4G USB passthrough enabled (bridge/setup in OpenWRT)"
echo "• GUI container (Weston) running; for UI apps"
