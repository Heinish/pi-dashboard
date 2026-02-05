#!/bin/bash
# Raspberry Pi Dashboard Auto-Installer
# This script installs the dashboard and sets it up to auto-start on boot

set -e  # Exit on any error

echo "🍓 Raspberry Pi Dashboard Auto-Installer"
echo "=========================================="
echo ""

# Get the current user and home directory
CURRENT_USER=$(whoami)
HOME_DIR="${HOME:-$(eval echo ~$CURRENT_USER)}"
INSTALL_DIR="$HOME_DIR/pi-dashboard"

# Verify home directory exists
if [ ! -d "$HOME_DIR" ]; then
    echo "❌ Error: Home directory $HOME_DIR does not exist!"
    exit 1
fi

echo "📍 Installation directory: $INSTALL_DIR"
echo "👤 Running as user: $CURRENT_USER"
echo "🏠 Home directory: $HOME_DIR"
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

# Check for git
if ! command -v git &> /dev/null; then
    echo "❌ Error: git is not installed. Please install it first:"
    echo "   sudo apt-get update && sudo apt-get install -y git"
    exit 1
fi

# Clone the repository
echo "📥 Cloning repository..."
cd "$HOME_DIR"
if ! git clone https://github.com/Heinish/pi-dashboard.git; then
    echo "❌ Error: Failed to clone repository. Please check your internet connection."
    exit 1
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
if ! pip3 install flask requests --break-system-packages 2>/dev/null; then
    if ! pip3 install flask requests; then
        echo "❌ Error: Failed to install Python dependencies."
        exit 1
    fi
fi

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
sleep 3

# Check if service is running
if sudo systemctl is-active --quiet pi-dashboard; then
    echo ""
    echo "✅ SUCCESS! Dashboard installed and running!"
    echo ""
    echo "📊 Dashboard is accessible at:"
    echo "   - http://localhost:8080"
    
    # Try to get IP address
    if command -v hostname &> /dev/null; then
        IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [ -n "$IP_ADDR" ]; then
            echo "   - http://$IP_ADDR:8080"
        fi
    fi
    
    echo ""
    echo "🔧 Useful commands:"
    echo "   - Check status:  sudo systemctl status pi-dashboard"
    echo "   - View logs:     sudo journalctl -u pi-dashboard -f"
    echo "   - Restart:       sudo systemctl restart pi-dashboard"
    echo "   - Stop:          sudo systemctl stop pi-dashboard"
    echo "   - Disable:       sudo systemctl disable pi-dashboard"
    echo ""
    echo "🎉 The dashboard will automatically start on boot!"
    echo ""
else
    echo ""
    echo "⚠️  Service may have issues. Checking logs..."
    echo ""
    sudo journalctl -u pi-dashboard -n 20 --no-pager
    echo ""
    echo "💡 Try checking the full logs with:"
    echo "   sudo journalctl -u pi-dashboard -f"
fi