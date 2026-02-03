#!/bin/bash
# Raspberry Pi Dashboard Auto-Install Script
# This script installs the dashboard and sets it up to auto-start on boot

set -e  # Exit on any error

echo "🍓 Raspberry Pi Dashboard Auto-Installer"
echo "=========================================="
echo ""

# Get the current user
CURRENT_USER=$(whoami)
INSTALL_DIR="/home/$CURRENT_USER/pi-dashboard"

echo "📍 Installation directory: $INSTALL_DIR"
echo "👤 Running as user: $CURRENT_USER"
echo ""

# Check if already installed
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  Dashboard directory already exists at $INSTALL_DIR"
    read -p "Do you want to remove it and reinstall? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing old installation..."
        rm -rf "$INSTALL_DIR"
    else
        echo "❌ Installation cancelled."
        exit 1
    fi
fi

# Clone the repository
echo "📥 Cloning repository..."
cd "/home/$CURRENT_USER"
git clone https://github.com/Heinish/pi-dashboard.git

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install flask requests --break-system-packages 2>/dev/null || pip3 install flask requests

# Create the systemd service file
echo "⚙️  Creating systemd service..."
sudo tee /etc/systemd/system/pi-dashboard.service > /dev/null << EOF
[Unit]
Description=Raspberry Pi Dashboard Server
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/dashboard_server.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
echo "🚀 Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable pi-dashboard
sudo systemctl start pi-dashboard

# Wait a moment for the service to start
sleep 2

# Check if service is running
if sudo systemctl is-active --quiet pi-dashboard; then
    echo ""
    echo "✅ SUCCESS! Dashboard installed and running!"
    echo ""
    echo "📊 Dashboard is accessible at:"
    echo "   - http://localhost:8080"
    echo "   - http://$(hostname -I | awk '{print $1}'):8080"
    echo ""
    echo "🔧 Useful commands:"
    echo "   - Check status:  sudo systemctl status pi-dashboard"
    echo "   - View logs:     sudo journalctl -u pi-dashboard -f"
    echo "   - Restart:       sudo systemctl restart pi-dashboard"
    echo "   - Stop:          sudo systemctl stop pi-dashboard"
    echo "   - Disable:       sudo systemctl disable pi-dashboard"
    echo ""
    echo "🎉 The dashboard will automatically start on boot!"
else
    echo ""
    echo "⚠️  Service started but may have issues. Check logs with:"
    echo "   sudo journalctl -u pi-dashboard -n 50"
fi
