#!/bin/bash
# Super Simple Pi Agent Installer with Display Resolution Configuration
echo "======================================"
echo "Installing Pi Dashboard Agent..."
echo "======================================"

# Prompt for display resolution
echo ""
echo "Select display resolution:"
echo "1) 1920x1080 (Full HD)"
echo "2) 1280x720 (HD)"
echo "3) 1024x768"
echo "4) 800x600"
echo "5) Custom (enter manually)"
echo "6) Skip (no resolution change)"
read -p "Enter choice [1-6]: " resolution_choice

case $resolution_choice in
    1)
        RESOLUTION="1920x1080"
        ;;
    2)
        RESOLUTION="1280x720"
        ;;
    3)
        RESOLUTION="1024x768"
        ;;
    4)
        RESOLUTION="800x600"
        ;;
    5)
        read -p "Enter custom resolution (e.g., 1920x1080): " RESOLUTION
        ;;
    6)
        RESOLUTION=""
        echo "Skipping resolution configuration"
        ;;
    *)
        echo "Invalid choice, skipping resolution configuration"
        RESOLUTION=""
        ;;
esac

# Apply resolution if specified
if [ -n "$RESOLUTION" ]; then
    echo "Setting display resolution to $RESOLUTION..."
    
    # Update config.txt for display resolution
    CONFIG_FILE="/boot/config.txt"
    if [ ! -f "$CONFIG_FILE" ]; then
        CONFIG_FILE="/boot/firmware/config.txt"
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        # Extract width and height
        WIDTH=$(echo $RESOLUTION | cut -d'x' -f1)
        HEIGHT=$(echo $RESOLUTION | cut -d'x' -f2)
        
        # Backup config
        sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
        
        # Remove old hdmi settings if they exist
        sudo sed -i '/^hdmi_mode=/d' "$CONFIG_FILE"
        sudo sed -i '/^hdmi_group=/d' "$CONFIG_FILE"
        sudo sed -i '/^hdmi_cvt=/d' "$CONFIG_FILE"
        
        # Add new resolution settings
        echo "" | sudo tee -a "$CONFIG_FILE" > /dev/null
        echo "# Display resolution set by pi-agent installer" | sudo tee -a "$CONFIG_FILE" > /dev/null
        echo "hdmi_group=2" | sudo tee -a "$CONFIG_FILE" > /dev/null
        echo "hdmi_mode=87" | sudo tee -a "$CONFIG_FILE" > /dev/null
        echo "hdmi_cvt=$WIDTH $HEIGHT 60 6 0 0 0" | sudo tee -a "$CONFIG_FILE" > /dev/null
        
        echo "✅ Resolution set to $RESOLUTION (requires reboot to take effect)"
    else
        echo "⚠️  Config file not found, skipping resolution configuration"
    fi
fi

echo ""
echo "Creating agent directory and script..."

# Create directory and agent script
mkdir -p ~/pi-agent

cat > ~/pi-agent/pi_agent.py << 'EOF'
#!/usr/bin/env python3
from flask import Flask, request, jsonify
import subprocess, os, socket
from datetime import datetime

app = Flask(__name__)

def get_config_path():
    for path in ["/boot/fullpageos.txt", "/boot/firmware/fullpageos.txt"]:
        if os.path.exists(path): return path
    return None

def run_command(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        return {'success': True, 'output': result.stdout.strip(), 'error': result.stderr.strip()}
    except Exception as e:
        return {'success': False, 'error': str(e)}

@app.route('/health')
def health():
    return jsonify({'status': 'ok', 'timestamp': datetime.now().isoformat()})

@app.route('/status')
def status():
    config_path = get_config_path()
    current_url = "Unknown"
    if config_path:
        try:
            with open(config_path, 'r') as f:
                current_url = f.readline().strip()
        except: pass
    return jsonify({
        'hostname': socket.gethostname(),
        'uptime': run_command("uptime -p").get('output', 'Unknown'),
        'current_url': current_url,
        'memory': run_command("free -h | grep Mem | awk '{print $3\"/\"$2}'").get('output', 'Unknown'),
        'temperature': run_command("vcgencmd measure_temp | cut -d= -f2").get('output', 'Unknown'),
        'cpu_usage': run_command("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1").get('output', 'Unknown'),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/url', methods=['POST'])
def change_url():
    new_url = request.get_json().get('url')
    if not new_url: return jsonify({'success': False, 'error': 'No URL'}), 400
    config_path = get_config_path()
    if not config_path: return jsonify({'success': False, 'error': 'Config not found'}), 500
    try:
        # Simply overwrite the entire file with just the new URL
        with open(config_path, 'w') as f:
            f.write(f'{new_url}\n')
        return jsonify({'success': True, 'message': f'URL updated to {new_url}', 'new_url': new_url})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/restart-browser', methods=['POST'])
def restart_browser():
    result = run_command("pkill chromium")
    return jsonify({'success': result['success'], 'message': 'Browser restarted' if result['success'] else result.get('error')})

@app.route('/reboot', methods=['POST'])
def reboot():
    subprocess.Popen(['sudo reboot'])
    return jsonify({'success': True, 'message': 'Pi is rebooting...'})

@app.route('/resolution', methods=['POST'])
def change_resolution():
    resolution = request.get_json().get('resolution')
    if not resolution: return jsonify({'success': False, 'error': 'No resolution provided'}), 400
    
    try:
        # Extract width and height
        width, height = resolution.split('x')
        
        # Find config file
        config_file = None
        for path in ["/boot/config.txt", "/boot/firmware/config.txt"]:
            if os.path.exists(path):
                config_file = path
                break
        
        if not config_file:
            return jsonify({'success': False, 'error': 'Config file not found'}), 500
        
        # Read current config
        with open(config_file, 'r') as f:
            lines = f.readlines()
        
        # Remove old hdmi settings
        lines = [l for l in lines if not any(x in l for x in ['hdmi_mode=', 'hdmi_group=', 'hdmi_cvt=', '# Display resolution set by'])]
        
        # Add new resolution settings
        lines.append('\\n')
        lines.append('# Display resolution set by pi-agent\\n')
        lines.append('hdmi_group=2\\n')
        lines.append('hdmi_mode=87\\n')
        lines.append(f'hdmi_cvt={width} {height} 60 6 0 0 0\\n')
        
        # Write back
        with open(config_file, 'w') as f:
            f.writelines(lines)
        
        return jsonify({'success': True, 'message': f'Resolution set to {resolution}. Reboot required to apply.'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

chmod +x ~/pi-agent/pi_agent.py

echo "Installing Flask..."
# Install Flask - try with --break-system-packages first (for newer Raspberry Pi OS)
pip3 install flask --break-system-packages 2>/dev/null || \
sudo apt install python3-flask -y 2>/dev/null || \
pip3 install flask

echo "Creating systemd service..."
# Create service with dynamic user and path
sudo tee /etc/systemd/system/pi-agent.service > /dev/null << EOF
[Unit]
Description=Raspberry Pi Dashboard Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$HOME/pi-agent
ExecStart=/usr/bin/python3 $HOME/pi-agent/pi_agent.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "Starting service..."
# Start service
sudo systemctl daemon-reload
sudo systemctl enable pi-agent
sudo systemctl start pi-agent

sleep 2

# Check status
echo ""
echo "======================================"
if sudo systemctl is-active --quiet pi-agent; then
    echo "✅ SUCCESS! Agent is running on port 5000"
    echo "Hostname: $(hostname)"
    echo "Test it: curl http://localhost:5000/health"
else
    echo "⚠️  Service may have issues"
    echo "Check status: sudo systemctl status pi-agent"
    echo "Check logs: sudo journalctl -u pi-agent -n 20"
fi
echo "======================================"

if [ -n "$RESOLUTION" ]; then
    echo ""
    read -p "Reboot now to apply display resolution? (y/n): " reboot_choice
    if [ "$reboot_choice" = "y" ] || [ "$reboot_choice" = "Y" ]; then
        echo "Rebooting in 5 seconds..."
        sleep 5
        sudo reboot
    fi
fi
