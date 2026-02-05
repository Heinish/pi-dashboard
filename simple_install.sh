#!/bin/bash

echo "🍓 Installing Pi Dashboard Agent..."

# Install dependencies
echo "📦 Installing Flask..."
sudo apt-get update -qq
sudo apt-get install -y python3-flask python3-pip python3-psutil -qq

# Create agent directory
mkdir -p /home/$USER/pi-agent
cd /home/$USER/pi-agent

# Download or create the agent script
echo "📝 Creating agent script..."
cat > agent.py << 'EOL'
#!/usr/bin/env python3
from flask import Flask, jsonify, request
import subprocess
import os
import psutil
from datetime import datetime

# Version tracking
AGENT_VERSION = "1.0.0"

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})

@app.route('/version', methods=['GET'])
def get_version():
    """Return agent version and last modified time"""
    try:
        script_path = __file__
        mod_time = os.path.getmtime(script_path)
        mod_date = datetime.fromtimestamp(mod_time).strftime('%Y-%m-%d %H:%M:%S')
        
        return jsonify({
            'version': AGENT_VERSION,
            'last_modified': mod_date,
            'timestamp': mod_time,
            'status': 'ok'
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/status', methods=['GET'])
def status():
    """Get Pi status information"""
    try:
        # Get uptime
        uptime_seconds = int(psutil.boot_time())
        current_time = int(datetime.now().timestamp())
        uptime_delta = current_time - uptime_seconds
        days = uptime_delta // 86400
        hours = (uptime_delta % 86400) // 3600
        uptime_str = f"{days}d {hours}h"
        
        # Get CPU and memory
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        
        # Get temperature (Raspberry Pi specific)
        try:
            temp_output = subprocess.check_output(['vcgencmd', 'measure_temp']).decode()
            temp = temp_output.replace('temp=', '').replace("'C\n", '')
        except:
            temp = 'N/A'
        
        # Get current URL from FullPageOS config
        current_url = 'Unknown'
        config_paths = ['/boot/fullpageos.txt', '/boot/firmware/fullpageos.txt']
        for config_path in config_paths:
            if os.path.exists(config_path):
                try:
                    with open(config_path, 'r') as f:
                        for line in f:
                            if line.startswith('fullpageos_url='):
                                current_url = line.split('=', 1)[1].strip().strip('"')
                                break
                except:
                    pass
                break
        
        return jsonify({
            'status': 'online',
            'uptime': uptime_str,
            'cpu': f"{cpu_percent}%",
            'memory': f"{memory.percent}%",
            'temperature': temp,
            'current_url': current_url,
            'version': AGENT_VERSION
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/url', methods=['POST'])
def set_url():
    """Change the URL displayed on the Pi"""
    try:
        data = request.get_json()
        new_url = data.get('url')
        
        if not new_url:
            return jsonify({'error': 'No URL provided'}), 400
        
        # Find and update FullPageOS config
        config_paths = ['/boot/fullpageos.txt', '/boot/firmware/fullpageos.txt']
        config_updated = False
        
        for config_path in config_paths:
            if os.path.exists(config_path):
                try:
                    # Read current config
                    with open(config_path, 'r') as f:
                        lines = f.readlines()
                    
                    # Update URL line
                    with open(config_path, 'w') as f:
                        for line in lines:
                            if line.startswith('fullpageos_url='):
                                f.write(f'fullpageos_url="{new_url}"\n')
                            else:
                                f.write(line)
                    
                    config_updated = True
                    break
                except PermissionError:
                    return jsonify({'error': 'Permission denied. Run: sudo chmod 666 ' + config_path}), 500
                except Exception as e:
                    return jsonify({'error': str(e)}), 500
        
        if not config_updated:
            return jsonify({'error': 'FullPageOS config file not found'}), 404
        
        # Restart the browser to apply changes
        try:
            subprocess.run(['sudo', 'systemctl', 'restart', 'fullpageos'], check=False)
        except:
            pass
        
        return jsonify({
            'status': 'success',
            'message': f'URL updated to {new_url}',
            'new_url': new_url
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/restart-browser', methods=['POST'])
def restart_browser():
    """Restart the Chromium browser"""
    try:
        subprocess.run(['sudo', 'systemctl', 'restart', 'fullpageos'], check=True)
        return jsonify({'status': 'success', 'message': 'Browser restarted'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/reboot', methods=['POST'])
def reboot():
    """Reboot the Pi"""
    try:
        subprocess.Popen(['sudo', 'reboot'])
        return jsonify({'status': 'success', 'message': 'Rebooting...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/update', methods=['POST'])
def update_agent():
    """Update the agent by re-running the install script"""
    try:
        # Run the install script
        install_cmd = 'curl -sSL https://raw.githubusercontent.com/Heinish/pi-dashboard/main/simple_install.sh | bash'
        subprocess.Popen(install_cmd, shell=True)
        
        return jsonify({
            'status': 'success',
            'message': 'Update started. Agent will restart in a few seconds.'
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOL

chmod +x agent.py

# Create systemd service
echo "⚙️  Creating systemd service..."
sudo tee /etc/systemd/system/pi-agent.service > /dev/null << EOF
[Unit]
Description=Pi Dashboard Agent
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/pi-agent
ExecStart=/usr/bin/python3 /home/$USER/pi-agent/agent.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "🚀 Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable pi-agent
sudo systemctl restart pi-agent

# Wait a moment and check status
sleep 2
if sudo systemctl is-active --quiet pi-agent; then
    echo "✅ Installation complete!"
    echo ""
    echo "Agent is running on port 5000"
    echo "Check status: sudo systemctl status pi-agent"
    echo "View logs: sudo journalctl -u pi-agent -f"
    echo ""
    echo "Add this Pi to your dashboard:"
    echo "IP: $(hostname -I | awk '{print $1}')"
else
    echo "❌ Service failed to start. Check logs:"
    sudo journalctl -u pi-agent -n 20
fi
