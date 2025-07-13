#!/bin/bash

# Update and install XFCE, RDP, Browsers, and utilities
apt-get update && apt-get upgrade -y

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-goodies xrdp ufw snapd curl gnupg \
    apt-transport-https software-properties-common \
    htop iotop iftop ncdu git unzip jq lsb-release \
    iputils-ping traceroute net-tools fuse

# Setup RDP
echo 'ubuntu:Atharv12' | chpasswd
echo "startxfce4" > /home/ubuntu/.xsession
chown ubuntu:ubuntu /home/ubuntu/.xsession
systemctl enable xrdp
systemctl start xrdp
ufw allow 3389
ufw --force enable

# Install Firefox
snap install firefox

# Install Brave Browser
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
apt-get update
apt-get install -y brave-browser

# Write rclone.conf (injected via GitHub Actions)
mkdir -p /home/ubuntu/.config/rclone
cat <<EOF > /home/ubuntu/.config/rclone/rclone.conf
__RCLONE_CONF__
EOF
chown -R ubuntu:ubuntu /home/ubuntu/.config/rclone
chmod 600 /home/ubuntu/.config/rclone/rclone.conf

# Mount Google Drive
mkdir -p /home/ubuntu/GDrive
chown ubuntu:ubuntu /home/ubuntu/GDrive
su - ubuntu -c "rclone mount gdrive: /home/ubuntu/GDrive --vfs-cache-mode writes --daemon"
