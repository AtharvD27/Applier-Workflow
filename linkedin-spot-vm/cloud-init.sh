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

# Install lightweight desktop (LXDE)
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

# Wait for browser volume to be available
echo "Waiting for browser volume to be attached..."
sleep 60

# Check if browser volume is attached and mount it
if [ -b /dev/xvdf ]; then
    echo "Browser volume detected, mounting..."
    
    # Create mount point
    mkdir -p /mnt/browsers
    
    # Mount the browser volume
    mount /dev/xvdf /mnt/browsers
    
    # Add to fstab for automatic mounting on boot
    BROWSER_UUID=$(blkid -s UUID -o value /dev/xvdf)
    echo "UUID=$BROWSER_UUID /mnt/browsers ext4 defaults 0 2" >> /etc/fstab
    
    echo "Browser volume mounted successfully!"
else
    echo "Browser volume not found, creating placeholder directory..."
    mkdir -p /mnt/browsers
    chown ubuntu:ubuntu /mnt/browsers
fi

# Install Brave Browser (for instances where browser volume doesn't have it)
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
apt-get update
apt-get install -y brave-browser

# Install Firefox as backup
snap install firefox

# Create browser launcher scripts
cat > /home/ubuntu/launch-brave-normal.sh << 'EOF'
#!/bin/bash
# Normal Brave with all features enabled
brave-browser \
  --user-data-dir=/mnt/browsers/brave-data \
  --no-first-run \
  --no-default-browser-check \
  "$@"
EOF

cat > /home/ubuntu/launch-brave-optimized.sh << 'EOF'
#!/bin/bash
# Optimized Brave for better RDP performance
brave-browser \
  --user-data-dir=/mnt/browsers/brave-data \
  --disable-gpu \
  --disable-software-rasterizer \
  --disable-background-timer-throttling \
  --disable-renderer-backgrounding \
  --disable-backgrounding-occluded-windows \
  --disable-features=TranslateUI,VizDisplayCompositor,AudioServiceOutOfProcess \
  --disable-background-networking \
  --disable-component-extensions-with-background-pages \
  --no-first-run \
  --no-default-browser-check \
  --memory-pressure-off \
  --max_old_space_size=512 \
  --process-per-site \
  "$@"
EOF

cat > /home/ubuntu/launch-firefox.sh << 'EOF'
#!/bin/bash
# Firefox with persistent profile on browser volume
if [ ! -d "/mnt/browsers/firefox-data/profile" ]; then
    mkdir -p /mnt/browsers/firefox-data/profile
    firefox -CreateProfile "persistent /mnt/browsers/firefox-data/profile"
fi
firefox -profile /mnt/browsers/firefox-data/profile "$@"
EOF

# Make scripts executable
chmod +x /home/ubuntu/launch-brave-normal.sh
chmod +x /home/ubuntu/launch-brave-optimized.sh
chmod +x /home/ubuntu/launch-firefox.sh

# Create symlinks for easy access
ln -sf /home/ubuntu/launch-brave-normal.sh /home/ubuntu/brave
ln -sf /home/ubuntu/launch-brave-optimized.sh /home/ubuntu/brave-opt
ln -sf /home/ubuntu/launch-firefox.sh /home/ubuntu/firefox

# Create desktop shortcuts
mkdir -p /home/ubuntu/Desktop

cat > /home/ubuntu/Desktop/brave-normal.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Brave (Normal)
Comment=Brave Browser with Full Features
Exec=/home/ubuntu/launch-brave-normal.sh
Icon=brave-browser
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

cat > /home/ubuntu/Desktop/brave-optimized.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Brave (Optimized)
Comment=Brave Browser Optimized for RDP Performance
Exec=/home/ubuntu/launch-brave-optimized.sh
Icon=brave-browser
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

cat > /home/ubuntu/Desktop/firefox-persistent.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Firefox (Persistent)
Comment=Firefox with Persistent Profile
Exec=/home/ubuntu/launch-firefox.sh
Icon=firefox
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

# Make desktop shortcuts executable
chmod +x /home/ubuntu/Desktop/*.desktop

# Create browser volume status check script
cat > /home/ubuntu/check-browsers.sh << 'EOF'
#!/bin/bash
echo "=== Browser Volume Status ==="
if mountpoint -q /mnt/browsers; then
    echo "✅ Browser volume is mounted"
    echo "Available space:"
    df -h /mnt/browsers
    echo ""
    echo "Browser data directories:"
    ls -la /mnt/browsers/
else
    echo "❌ Browser volume is not mounted"
    echo "Attempting to mount..."
    sudo mount /dev/xvdf /mnt/browsers 2>/dev/null
    if mountpoint -q /mnt/browsers; then
        echo "✅ Successfully mounted browser volume"
    else
        echo "❌ Failed to mount browser volume"
    fi
fi

echo ""
echo "=== Available Browser Launchers ==="
echo "Normal Brave:     ~/brave"
echo "Optimized Brave:  ~/brave-opt  (recommended for LinkedIn)"
echo "Firefox:          ~/firefox"
EOF
chmod +x /home/ubuntu/check-browsers.sh

# Set proper ownership for all user files
chown -R ubuntu:ubuntu /home/ubuntu/

# Ensure browser volume directories exist
mkdir -p /mnt/browsers/brave-data
mkdir -p /mnt/browsers/firefox-data
mkdir -p /mnt/browsers/downloads
chown -R ubuntu:ubuntu /mnt/browsers/

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

echo "Setup complete! Browser volume ready for use."
echo "Password saved to /home/ubuntu/password.txt"
echo "Run ~/check-browsers.sh to verify browser volume status"