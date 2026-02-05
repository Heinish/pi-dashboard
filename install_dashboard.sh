#!/usr/bin/env python3
from flask import Flask, render_template, request, jsonify
import requests
import json
import os
from datetime import datetime

app = Flask(__name__)

# Version info
DASHBOARD_VERSION = "1.0.0"
EXPECTED_AGENT_VERSION = "1.0.0"

# File to store Pi configurations
CONFIG_FILE = 'pis_config.json'

def load_pis():
    """Load Pi configurations from file"""
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    return []

def save_pis(pis):
    """Save Pi configurations to file"""
    with open(CONFIG_FILE, 'w') as f:
        json.dump(pis, f, indent=2)

def get_pi_status(ip):
    """Get status information from a Pi"""
    status = {
        'online': False,
        'uptime': 'N/A',
        'cpu': 'N/A',
        'memory': 'N/A',
        'temperature': 'N/A',
        'current_url': 'Unknown',
        'version': 'Unknown',
        'last_modified': 'Unknown',
        'needs_update': False
    }
    
    try:
        # Check if Pi is online
        health_response = requests.get(f'http://{ip}:5000/health', timeout=2)
        if health_response.status_code == 200:
            status['online'] = True
            
            # Get version info
            try:
                version_response = requests.get(f'http://{ip}:5000/version', timeout=2)
                if version_response.status_code == 200:
                    version_data = version_response.json()
                    status['version'] = version_data.get('version', 'Unknown')
                    status['last_modified'] = version_data.get('last_modified', 'Unknown')
                    status['needs_update'] = status['version'] != EXPECTED_AGENT_VERSION
            except:
                pass
            
            # Get detailed status
            try:
                status_response = requests.get(f'http://{ip}:5000/status', timeout=2)
                if status_response.status_code == 200:
                    data = status_response.json()
                    status['uptime'] = data.get('uptime', 'N/A')
                    status['cpu'] = data.get('cpu', 'N/A')
                    status['memory'] = data.get('memory', 'N/A')
                    status['temperature'] = data.get('temperature', 'N/A')
                    status['current_url'] = data.get('current_url', 'Unknown')
            except:
                pass
    except:
        pass
    
    return status

@app.route('/')
def index():
    """Main dashboard page"""
    pis = load_pis()
    
    # Get status for each Pi
    for pi in pis:
        pi_status = get_pi_status(pi['ip'])
        pi.update(pi_status)
    
    return render_template('dashboard.html', 
                         pis=pis, 
                         dashboard_version=DASHBOARD_VERSION,
                         expected_agent_version=EXPECTED_AGENT_VERSION)

@app.route('/api/add_pi', methods=['POST'])
def add_pi():
    """Add a new Pi to the dashboard"""
    data = request.get_json()
    ip = data.get('ip')
    name = data.get('name')
    
    if not ip or not name:
        return jsonify({'error': 'IP and name are required'}), 400
    
    pis = load_pis()
    
    # Check if IP already exists
    if any(pi['ip'] == ip for pi in pis):
        return jsonify({'error': 'Pi with this IP already exists'}), 400
    
    pis.append({'ip': ip, 'name': name})
    save_pis(pis)
    
    return jsonify({'status': 'success', 'message': f'Added {name}'})

@app.route('/api/remove_pi', methods=['POST'])
def remove_pi():
    """Remove a Pi from the dashboard"""
    data = request.get_json()
    ip = data.get('ip')
    
    pis = load_pis()
    pis = [pi for pi in pis if pi['ip'] != ip]
    save_pis(pis)
    
    return jsonify({'status': 'success'})

@app.route('/api/update_name', methods=['POST'])
def update_name():
    """Update a Pi's name"""
    data = request.get_json()
    ip = data.get('ip')
    new_name = data.get('name')
    
    pis = load_pis()
    for pi in pis:
        if pi['ip'] == ip:
            pi['name'] = new_name
            break
    save_pis(pis)
    
    return jsonify({'status': 'success'})

@app.route('/api/set_url', methods=['POST'])
def set_url():
    """Set URL on a Pi"""
    data = request.get_json()
    ip = data.get('ip')
    url = data.get('url')
    
    try:
        response = requests.post(
            f'http://{ip}:5000/url',
            json={'url': url},
            timeout=5
        )
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/restart_browser', methods=['POST'])
def restart_browser():
    """Restart browser on a Pi"""
    data = request.get_json()
    ip = data.get('ip')
    
    try:
        response = requests.post(f'http://{ip}:5000/restart-browser', timeout=5)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/reboot', methods=['POST'])
def reboot():
    """Reboot a Pi"""
    data = request.get_json()
    ip = data.get('ip')
    
    try:
        response = requests.post(f'http://{ip}:5000/reboot', timeout=5)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/update_agent', methods=['POST'])
def update_agent():
    """Update the agent on a Pi"""
    data = request.get_json()
    ip = data.get('ip')
    
    try:
        response = requests.post(f'http://{ip}:5000/update', timeout=5)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/bulk_set_url', methods=['POST'])
def bulk_set_url():
    """Set URL on multiple Pis"""
    data = request.get_json()
    ips = data.get('ips', [])
    url = data.get('url')
    
    results = []
    for ip in ips:
        try:
            response = requests.post(
                f'http://{ip}:5000/url',
                json={'url': url},
                timeout=5
            )
            results.append({'ip': ip, 'status': 'success'})
        except Exception as e:
            results.append({'ip': ip, 'status': 'error', 'error': str(e)})
    
    return jsonify({'results': results})

@app.route('/api/bulk_restart_browser', methods=['POST'])
def bulk_restart_browser():
    """Restart browser on multiple Pis"""
    data = request.get_json()
    ips = data.get('ips', [])
    
    results = []
    for ip in ips:
        try:
            response = requests.post(f'http://{ip}:5000/restart-browser', timeout=5)
            results.append({'ip': ip, 'status': 'success'})
        except Exception as e:
            results.append({'ip': ip, 'status': 'error', 'error': str(e)})
    
    return jsonify({'results': results})

@app.route('/api/bulk_update', methods=['POST'])
def bulk_update():
    """Update agents on multiple Pis"""
    data = request.get_json()
    ips = data.get('ips', [])
    
    results = []
    for ip in ips:
        try:
            response = requests.post(f'http://{ip}:5000/update', timeout=5)
            results.append({'ip': ip, 'status': 'success'})
        except Exception as e:
            results.append({'ip': ip, 'status': 'error', 'error': str(e)})
    
    return jsonify({'results': results})

if __name__ == '__main__':
    print("🍓 Raspberry Pi Dashboard Server")
    print(f"Version: {DASHBOARD_VERSION}")
    print(f"Expected Agent Version: {EXPECTED_AGENT_VERSION}")
    print("\nStarting server on http://localhost:8080")
    print("Press Ctrl+C to stop\n")
    app.run(host='0.0.0.0', port=8080, debug=True)
