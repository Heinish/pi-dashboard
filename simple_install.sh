#!/usr/bin/env python3
from flask import Flask, request, jsonify
import subprocess, os, socket
from datetime import datetime

app = Flask(__name__)

def get_config_path():
    for path in ["/boot/fullpageos.txt", "/boot/firmware/fullpageos.txt"]:
        if os.path.exists(path): 
            return path
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
        except: 
            pass
    
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
    if not new_url: 
        return jsonify({'success': False, 'error': 'No URL'}), 400
    
    config_path = get_config_path()
    if not config_path: 
        return jsonify({'success': False, 'error': 'Config not found'}), 500
    
    try:
        # Simply overwrite the entire file with just the new URL
        with open(config_path, 'w') as f:
            f.write(f'{new_url}\n')
        
        # Restart the browser to load the new URL
        browser_result = run_command("pkill chromium")
        
        return jsonify({
            'success': True,
            'message': f'URL updated to {new_url} and browser restarted',
            'new_url': new_url,
            'browser_restart': browser_result
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/reboot', methods=['POST'])
def reboot():
    try:
        run_command("sudo reboot")
        return jsonify({'success': True, 'message': 'Rebooting...'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
