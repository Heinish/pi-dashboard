# 🍓 Raspberry Pi Dashboard

A simple web dashboard to manage multiple Raspberry Pi devices running FullPageOS from one central location.

![Dashboard](https://img.shields.io/badge/Raspberry%20Pi-Compatible-red?style=flat-square)
![Python](https://img.shields.io/badge/Python-3.7+-blue?style=flat-square)

## ✨ Features

- 🖥️ **Web-based dashboard** - Control all Pis from your browser
- 🔄 **Change URLs remotely** - Update what's displayed on any Pi
- ✏️ **Edit Pi names** - Click the pencil icon to rename any Pi
- 📊 **System monitoring** - View uptime, CPU, memory, and temperature
- ⚡ **Bulk actions** - Update multiple Pis at once
- 🚀 **Easy installation** - One command install via SSH
- 🔁 **Auto-restart** - Agent starts automatically on boot

## 🚀 Quick Start

### Step 1: Install Agent on Each Raspberry Pi

SSH into each Pi and run this one command:

```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/pi-dashboard/main/simple_install.sh | bash
```

**⚠️ Replace `YOUR_USERNAME` with your actual GitHub username!**

This installs a tiny agent (5KB, 15MB RAM) that runs on port 5000.

### Step 2: Set Up the Dashboard

On your main computer (or one designated Pi):

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/pi-dashboard.git
cd pi-dashboard

# Install Python dependencies
py -m pip install flask requests

# Start the dashboard
python3 dashboard_server.py
```

### Step 3: Access & Configure

1. Open your browser to: `http://localhost:8080`
2. Click **"➕ Add Pi"** 
3. Enter each Pi's **IP address** and a **friendly name**
4. Click **"Add"**

Done! 🎉

## 📖 Usage

### Managing Individual Pis

Each Pi card shows:
- ✅ Online/Offline status (green/red dot)
- Current URL being displayed
- System stats (uptime, CPU, memory, temperature)

**Actions you can take:**
- **✏️ Edit Name** - Click the pencil icon next to the Pi name
- **Change URL** - Enter a new URL and click "Set URL"
- **Restart Browser** - Restarts the Chromium browser
- **Reboot** - Reboots the entire Pi
- **Remove** - Removes Pi from dashboard

### Bulk Actions

1. Click **"📋 Bulk Actions"**
2. Check the Pis you want to control (or "Select All")
3. Choose an action:
   - **Change URL** - Set same URL on multiple Pis
   - **Restart Browsers** - Restart all selected browsers

### Auto-Refresh

Dashboard automatically refreshes every 30 seconds, or click **"🔄 Refresh"** anytime.

## 🛠️ Installation Details

### What Gets Installed on Each Pi?

- **Flask** (Python web framework)
- **Pi Agent Service** (systemd service, auto-starts on boot)
- **Install size:** ~5KB
- **Memory usage:** ~15MB
- **Port:** 5000

### Files Included

```
pi-dashboard/
├── simple_install.sh       # One-line installer for Pis
├── dashboard_server.py     # Main dashboard server
├── templates/
│   └── dashboard.html      # Web interface
└── README.md              # This file
```

## 🔧 Advanced Usage

### Manual Installation on Pi

If you prefer not to use the one-line installer:

```bash
# SSH into your Pi
ssh pi@192.168.1.101

# Download the installer
wget https://raw.githubusercontent.com/YOUR_USERNAME/pi-dashboard/main/simple_install.sh

# Make it executable
chmod +x simple_install.sh

# Run it
./simple_install.sh
```

### Check Agent Status

```bash
# Check if agent is running
sudo systemctl status pi-agent

# View logs
sudo journalctl -u pi-agent -f

# Restart agent
sudo systemctl restart pi-agent

# Test agent directly
curl http://localhost:5000/health
```

### Custom Dashboard Port

Edit `dashboard_server.py`, line 141:
```python
app.run(host='0.0.0.0', port=8080, debug=True)
```

Change `8080` to your desired port.

## 📡 API Endpoints

The agent on each Pi exposes these endpoints:

- `GET /health` - Health check
- `GET /status` - Get Pi status info
- `POST /url` - Change displayed URL
- `POST /restart-browser` - Restart Chromium
- `POST /reboot` - Reboot the Pi

Example:
```bash
# Change URL
curl -X POST http://192.168.1.101:5000/url \
  -H "Content-Type: application/json" \
  -d '{"url":"https://google.com"}'

# Get status
curl http://192.168.1.101:5000/status
```

## 🐛 Troubleshooting

### Pi shows as "Offline"

1. Check if agent is running:
   ```bash
   ssh pi@PI_IP
   sudo systemctl status pi-agent
   ```

2. Restart the agent:
   ```bash
   sudo systemctl restart pi-agent
   ```

3. Check firewall (if enabled):
   ```bash
   sudo ufw allow 5000
   ```

### Can't Change URL

The agent needs write access to FullPageOS config. Run:
```bash
sudo chmod 666 /boot/fullpageos.txt
# or
sudo chmod 666 /boot/firmware/fullpageos.txt
```

### Dashboard Won't Start

```bash
# Install dependencies
pip3 install flask requests

# Check if port 8080 is already in use
netstat -tuln | grep 8080
```

## 🔒 Security Notes

⚠️ **This system is designed for LOCAL NETWORK USE ONLY**

- No authentication implemented
- All communication is HTTP (not HTTPS)
- Agents accept commands from any source on the network

**For production use, add:**
- Authentication (API keys, passwords)
- HTTPS/TLS encryption
- Firewall rules
- Rate limiting

## 📋 Requirements

**Dashboard Server:**
- Python 3.7+
- Flask
- requests

**Raspberry Pi:**
- Python 3.7+
- Flask
- FullPageOS installed
- SSH enabled

## 🤝 Contributing

Feel free to fork, modify, and improve! This is a simple tool to make managing multiple Pis easier.

## 📄 License

Free to use and modify!

## 💡 Tips

- Use descriptive names like "Living Room", "Kitchen Display", etc.
- Set up SSH keys to avoid typing passwords repeatedly
- The dashboard config is saved in `pis_config.json`
- Agent logs: `sudo journalctl -u pi-agent -f`

---

**Made with ❤️ for managing multiple Raspberry Pis running FullPageOS**

Need help? Check the troubleshooting section above or create an issue!
