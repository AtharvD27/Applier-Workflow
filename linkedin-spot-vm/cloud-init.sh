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

# Wait and detect browser volume
echo "Waiting for browser volume to be attached..."
BROWSER_DEVICE=""
BROWSER_VOLUME_ID="vol-06834ddf3f58d41a8"

# Wait up to 3 minutes for the volume to appear
for i in {1..36}; do
    echo "Checking for browser volume... attempt $i/36"
    
    # Check multiple possible device names
    for device in /dev/xvdf /dev/nvme1n1 /dev/nvme2n1 /dev/sdf; do
        if [ -b "$device" ]; then
            # Verify this is our browser volume by checking size (8GB)
            DEVICE_SIZE=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -n1)
            if [ "$DEVICE_SIZE" = "8589934592" ]; then  # 8GB in bytes
                BROWSER_DEVICE="$device"
                echo "✅ Browser volume found at: $BROWSER_DEVICE"
                break 2
            fi
        fi
    done
    
    # Also try to find by AWS volume ID using nvme-cli (if available)
    if command -v nvme &> /dev/null; then
        for nvme_device in /dev/nvme*n1; do
            if [ -b "$nvme_device" ]; then
                NVME_INFO=$(nvme id-ctrl "$nvme_device" 2>/dev/null | grep -o "vol-[a-zA-Z0-9]*" | head -n1 || echo "")
                if [ "$NVME_INFO" = "$BROWSER_VOLUME_ID" ]; then
                    BROWSER_DEVICE="$nvme_device"
                    echo "✅ Browser volume found by volume ID at: $BROWSER_DEVICE"
                    break 2
                fi
            fi
        done
    fi
    
    sleep 5
done

# Mount the browser volume if found
if [ -n "$BROWSER_DEVICE" ]; then
    echo "Mounting browser volume from $BROWSER_DEVICE..."
    
    # Create mount point
    mkdir -p /mnt/browsers
    
    # Mount the browser volume (already formatted and configured)
    if mount "$BROWSER_DEVICE" /mnt/browsers; then
        echo "✅ Browser volume mounted successfully!"
        
        # Add to fstab for automatic mounting on boot
        BROWSER_UUID=$(blkid -s UUID -o value "$BROWSER_DEVICE")
        if [ -n "$BROWSER_UUID" ]; then
            echo "UUID=$BROWSER_UUID /mnt/browsers ext4 defaults 0 2" >> /etc/fstab
            echo "✅ Added to fstab for automatic mounting"
        fi
        
        # Set proper ownership
        chown -R ubuntu:ubuntu /mnt/browsers
        
        # Verify our data is there
        if [ -d "/mnt/browsers/scripts" ]; then
            echo "✅ Browser scripts found on volume"
        fi
        if [ -d "/mnt/browsers/Drive" ]; then
            echo "✅ Drive folder found on volume"
        fi
        if [ -d "/mnt/browsers/brave-data" ] || [ -d "/mnt/browsers/firefox-data" ]; then
            echo "✅ Browser profile data found on volume"
        fi
        
    else
        echo "❌ Failed to mount browser volume"
        mkdir -p /mnt/browsers
        chown ubuntu:ubuntu /mnt/browsers
    fi
else
    echo "❌ Browser volume not found after 3 minutes"
    echo "Available block devices:"
    lsblk
    echo "Creating placeholder directory..."
    mkdir -p /mnt/browsers
    chown ubuntu:ubuntu /mnt/browsers
fi

# Install browsers (binaries need to be installed on each instance)
echo "Installing browsers..."

# Install Brave Browser
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
apt-get update
apt-get install -y brave-browser

# Install Firefox
apt-get install -y firefox

# Create launcher scripts in home directory (pointing to EBS scripts)
echo "Creating launcher scripts..."

# Brave LinkedIn Optimized Launcher
cat > /home/ubuntu/brave-linkedin.sh << 'EOF'
#!/bin/bash
# Launch optimized Brave script from EBS volume
if [ -f "/mnt/browsers/scripts/brave-linkedin.sh" ]; then
    /mnt/browsers/scripts/brave-linkedin.sh "$@"
else
    echo "Optimized Brave script not found on EBS volume"
    brave-browser --user-data-dir=/mnt/browsers/brave-data "$@"
fi
EOF

# Firefox LinkedIn Optimized Launcher
cat > /home/ubuntu/firefox-linkedin.sh << 'EOF'
#!/bin/bash
# Launch optimized Firefox script from EBS volume
if [ -f "/mnt/browsers/scripts/firefox-linkedin.sh" ]; then
    /mnt/browsers/scripts/firefox-linkedin.sh "$@"
else
    echo "Optimized Firefox script not found on EBS volume"
    firefox -profile /mnt/browsers/firefox-data "$@"
fi
EOF

# Normal Brave Launcher (using EBS data directory)
cat > /home/ubuntu/brave-normal.sh << 'EOF'
#!/bin/bash
# Normal Brave with EBS data persistence
brave-browser \
  --user-data-dir=/mnt/browsers/brave-data \
  --no-first-run \
  --no-default-browser-check \
  "$@"
EOF

# Normal Firefox Launcher (using EBS data directory)
cat > /home/ubuntu/firefox-normal.sh << 'EOF'
#!/bin/bash
# Normal Firefox with EBS data persistence
mkdir -p /mnt/browsers/firefox-data
firefox -profile /mnt/browsers/firefox-data "$@"
EOF

# Make all scripts executable
chmod +x /home/ubuntu/*.sh

# Create desktop shortcuts
echo "Creating desktop shortcuts..."
mkdir -p /home/ubuntu/Desktop

# Brave LinkedIn Optimized shortcut
cat > /home/ubuntu/Desktop/Brave-LinkedIn-Optimized.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Brave LinkedIn (Optimized)
Comment=Brave Browser Optimized for LinkedIn Automation
Exec=/home/ubuntu/brave-linkedin.sh
Icon=brave-browser
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

# Firefox LinkedIn Optimized shortcut
cat > /home/ubuntu/Desktop/Firefox-LinkedIn-Optimized.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Firefox LinkedIn (Optimized)
Comment=Firefox Browser Optimized for LinkedIn Automation
Exec=/home/ubuntu/firefox-linkedin.sh
Icon=firefox
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

# Normal Brave shortcut
cat > /home/ubuntu/Desktop/Brave-Normal.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Brave (Normal)
Comment=Brave Browser with Full Features
Exec=/home/ubuntu/brave-normal.sh
Icon=brave-browser
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

# Normal Firefox shortcut
cat > /home/ubuntu/Desktop/Firefox-Normal.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Firefox (Normal)
Comment=Firefox Browser with Full Features
Exec=/home/ubuntu/firefox-normal.sh
Icon=firefox
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

# Browser Volume / Drive folder shortcut
cat > /home/ubuntu/Desktop/Drive-Folder.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Drive Folder
Comment=Access Drive folder on Browser Volume
Exec=pcmanfm /mnt/browsers/Drive
Icon=folder
Terminal=false
Categories=System;FileManager;
StartupNotify=true
EOF

# Browser Data folder shortcut (for easy access to all browser data)
cat > /home/ubuntu/Desktop/Browser-Data.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Browser Data
Comment=Access Browser Data on EBS Volume
Exec=pcmanfm /mnt/browsers
Icon=folder
Terminal=false
Categories=System;FileManager;
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
    echo ""
    echo "Available scripts on volume:"
    if [ -d "/mnt/browsers/scripts" ]; then
        ls -la /mnt/browsers/scripts/
    else
        echo "No scripts directory found"
    fi
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
echo "Optimized Brave:  ~/brave-linkedin.sh (recommended for automation)"
echo "Optimized Firefox: ~/firefox-linkedin.sh (backup for automation)"
echo "Normal Brave:     ~/brave-normal.sh"
echo "Normal Firefox:   ~/firefox-normal.sh"
echo ""
echo "=== Desktop Shortcuts Available ==="
echo "- Brave LinkedIn (Optimized)"
echo "- Firefox LinkedIn (Optimized)"
echo "- Brave (Normal)"
echo "- Firefox (Normal)"
echo "- Drive Folder"
echo "- Browser Data"
EOF
chmod +x /home/ubuntu/check-browsers.sh

# Set proper ownership for all user files
chown -R ubuntu:ubuntu /home/ubuntu/

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

echo "Setup complete! Browser volume with persistent data ready for use."
echo "Run ~/check-browsers.sh to verify browser volume status and available launchers"