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

# Brave optimizations for performance (software rendering)
mkdir -p /home/ubuntu/.config/BraveSoftware/Brave-Browser/Default

# Create performance-optimized Brave preferences
cat > /home/ubuntu/.config/BraveSoftware/Brave-Browser/Default/Preferences << EOF
{
   "profile": {
      "default_content_setting_values": {
         "notifications": 2,
         "images": 1,
         "javascript": 1,
         "plugins": 2,
         "popups": 2,
         "media_stream": 2
      }
   },
   "browser": {
      "check_default_browser": false,
      "show_home_button": false
   },
   "webkit": {
      "webprefs": {
         "fonts": {
            "standard": {
               "Zyyy": "Arial"
            }
         }
      }
   }
}
EOF

# Create Brave launcher script with performance flags
cat > /home/ubuntu/brave-performance.sh << 'EOF'
#!/bin/bash
brave-browser \
  --disable-gpu \
  --disable-software-rasterizer \
  --disable-background-timer-throttling \
  --disable-renderer-backgrounding \
  --disable-backgrounding-occluded-windows \
  --disable-features=TranslateUI,VizDisplayCompositor,AudioServiceOutOfProcess \
  --disable-extensions \
  --disable-plugins \
  --disable-sync \
  --disable-background-networking \
  --disable-default-apps \
  --disable-component-extensions-with-background-pages \
  --no-first-run \
  --no-default-browser-check \
  --memory-pressure-off \
  --max_old_space_size=512 \
  --process-per-site \
  --single-process \
  "$@"
EOF
chmod +x /home/ubuntu/brave-performance.sh

# Create desktop shortcut for optimized Brave
mkdir -p /home/ubuntu/Desktop
cat > /home/ubuntu/Desktop/brave-performance.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Brave (Performance Mode)
Comment=Brave Browser Optimized for Remote Desktop
Exec=/home/ubuntu/brave-performance.sh
Icon=brave-browser
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF
chmod +x /home/ubuntu/Desktop/brave-performance.desktop

# Install uBlock Origin extension data (for ad blocking = less resources)
mkdir -p /home/ubuntu/.config/BraveSoftware/Brave-Browser/Default/Extensions/cjpalhdlnbpafiamejdnhcphjbkeiagm
cat > /home/ubuntu/.config/BraveSoftware/Brave-Browser/Default/Extensions/external_extensions.json << EOF
{
  "cjpalhdlnbpafiamejdnhcphjbkeiagm": {
    "external_update_url": "https://clients2.google.com/service/update2/crx"
  }
}
EOF

chown -R ubuntu:ubuntu /home/ubuntu/.config /home/ubuntu/Desktop /home/ubuntu/brave-performance.sh

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