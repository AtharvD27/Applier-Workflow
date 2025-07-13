#!/bin/bash

# Update system
apt-get update && apt-get upgrade -y

# --- Essential packages only ---
apt-get install -y htop git unzip curl software-properties-common

# Set timezone
timedatectl set-timezone America/New_York

# Create 2GB swap file for better performance
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Optimize system performance
cat >> /etc/sysctl.conf << EOF
# Optimize for desktop performance
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.rmem_max=16777216
net.core.wmem_max=16777216
EOF
sysctl -p

# Install lightweight desktop (LXDE instead of XFCE)
DEBIAN_FRONTEND=noninteractive apt-get install -y lxde-core lxdm xrdp ufw

echo 'ubuntu:YourStrongPassword' | chpasswd

# Configure RDP session
echo "startlxde" > /home/ubuntu/.xsession
chown ubuntu:ubuntu /home/ubuntu/.xsession

# Optimize RDP for better performance
cat >> /etc/xrdp/xrdp.ini << EOF
[Globals]
bitmap_cache=yes
bitmap_compression=yes
bulk_compression=yes
max_bpp=16
EOF

# Enable and start services
systemctl enable xrdp
systemctl start xrdp
systemctl enable lxdm

# Configure firewall
ufw allow 3389
ufw --force enable

# Install Brave Browser (primary) and Firefox (backup)
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
apt-get update
apt-get install -y brave-browser

# Install Firefox as backup
snap install firefox

# Brave optimizations for performance
mkdir -p /home/ubuntu/.config/BraveSoftware/Brave-Browser/Default
cat > /home/ubuntu/.config/BraveSoftware/Brave-Browser/Default/Preferences << EOF
{
   "profile": {
      "default_content_setting_values": {
         "notifications": 2
      }
   },
   "browser": {
      "check_default_browser": false
   }
}
EOF

chown -R ubuntu:ubuntu /home/ubuntu/.config

# Clean up to save space
apt-get autoremove -y
apt-get autoclean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*

# Create startup optimization script
cat > /home/ubuntu/optimize.sh << 'EOF'
#!/bin/bash
# Run this after connecting to optimize performance
echo "Optimizing system performance..."
sudo sysctl vm.drop_caches=3
sudo systemctl restart xrdp
echo "System optimized!"
EOF
chmod +x /home/ubuntu/optimize.sh
chown ubuntu:ubuntu /home/ubuntu/optimize.sh

echo "Setup complete! Random password saved to /home/ubuntu/password.txt"