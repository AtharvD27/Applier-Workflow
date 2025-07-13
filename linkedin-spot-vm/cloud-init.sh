#!/bin/bash

# Update system
apt-get update && apt-get upgrade -y

# Set timezone
timedatectl set-timezone America/New_York

# Install XFCE GUI + RDP + firewall
DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 xfce4-goodies xrdp ufw snapd curl gnupg apt-transport-https software-properties-common

# Set ubuntu user password (for RDP login)
echo 'ubuntu:YourStrongPassword' | chpasswd

# Set XFCE as the default session for xRDP
echo "startxfce4" > /home/ubuntu/.xsession
chown ubuntu:ubuntu /home/ubuntu/.xsession

# Enable and start xRDP service
systemctl enable xrdp
systemctl start xrdp

# Allow RDP port and enable UFW
ufw allow 3389
ufw --force enable

# Install Firefox via Snap
snap install firefox
snap refresh firefox

# Install Brave Browser
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
apt-get update
apt-get install -y brave-browser
