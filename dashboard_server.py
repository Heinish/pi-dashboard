#!/usr/bin/env python3
"""
Pi Dashboard Server - Central management interface for all Raspberry Pis
"""
from flask import Flask, render_template, request, jsonify
import requests
from concurrent.futures import ThreadPoolExecutor
import json
import os

app = Flask(__name__)

# Configuration file for Pi list
CONFIG_FILE = 'pis_config.json'

def load_pis():
    """Load Pi configuration from JSON file"""
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    return []

def save_pis(pis):
    """Save Pi configuration to JSON file"""
    with open(CONFIG_FILE, 'w') as f:
        json.dump(pis, f, indent=2)

def query_pi(pi):
    """Query a single Pi for its status"""
    try:
        response = requests.get(f"http://{pi['ip']}:5000/status", timeout=5)
        if response.status_code == 200:
            data = response.json()
            return {
                'ip': pi['ip'],
                'name': pi['name'],
                'online': True,
                'data': data
            }
    except:
        pass
    
    return {
        'ip': pi['ip'],
        'name': pi['name'],
        'online': False,
        'data': {}
    }

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('dashboard.html')

@app.route('/api/pis', methods=['GET'])
def get_pis():
    """Get list of all configured Pis"""
    return jsonify(load_pis())

@app.route('/api/pis', methods=['POST'])
def add_pi():
    """Add a new Pi to the configuration"""
    data = request.get_json()
    pis = load_pis()
    
    # Check if IP already exists
    if any(pi['ip'] == data['ip'] for pi in pis):
        return jsonify({'success': False, 'error': 'Pi with this IP already exists'}), 400
    
    pis.append({
        'ip': data['ip'],
        'name': data.get('name', f"Pi {data['ip']}")
    })
    save_pis(pis)
    return jsonify({'success': True, 'pis': pis})

@app.route('/api/pis/<ip>', methods=['DELETE'])
def remove_pi(ip):
    """Remove a Pi from the configuration"""
    pis = load_pis()
    pis = [pi for pi in pis if pi['ip'] != ip]
    save_pis(pis)
    return jsonify({'success': True, 'pis': pis})

@app.route('/api/pis/<ip>/name', methods=['PUT'])
def update_pi_name(ip):
    """Update a Pi's name"""
    data = request.get_json()
    new_name = data.get('name')
    
    if not new_name:
        return jsonify({'success': False, 'error': 'No name provided'}), 400
    
    pis = load_pis()
    updated = False
    for pi in pis:
        if pi['ip'] == ip:
            pi['name'] = new_name
            updated = True
            break
    
    if not updated:
        return jsonify({'success': False, 'error': 'Pi not found'}), 404
    
    save_pis(pis)
    return jsonify({'success': True, 'message': 'Name updated', 'name': new_name})

@app.route('/api/status', methods=['GET'])
def get_all_status():
    """Get status of all Pis"""
    pis = load_pis()
    
    # Query all Pis in parallel
    with ThreadPoolExecutor(max_workers=10) as executor:
        results = list(executor.map(query_pi, pis))
    
    return jsonify(results)

@app.route('/api/command/<ip>/url', methods=['POST'])
def change_url(ip):
    """Change URL on a specific Pi"""
    data = request.get_json()
    try:
        response = requests.post(
            f"http://{ip}:5000/url",
            json={'url': data['url']},
            timeout=10
        )
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/command/<ip>/restart-browser', methods=['POST'])
def restart_browser(ip):
    """Restart browser on a specific Pi"""
    try:
        response = requests.post(f"http://{ip}:5000/restart-browser", timeout=10)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/command/<ip>/reboot', methods=['POST'])
def reboot_pi(ip):
    """Reboot a specific Pi"""
    try:
        response = requests.post(f"http://{ip}:5000/reboot", timeout=10)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/command/bulk/url', methods=['POST'])
def bulk_change_url():
    """Change URL on multiple Pis"""
    data = request.get_json()
    ips = data.get('ips', [])
    url = data.get('url')
    
    def change_single(ip):
        try:
            response = requests.post(
                f"http://{ip}:5000/url",
                json={'url': url},
                timeout=10
            )
            return {'ip': ip, 'success': True, 'response': response.json()}
        except Exception as e:
            return {'ip': ip, 'success': False, 'error': str(e)}
    
    with ThreadPoolExecutor(max_workers=10) as executor:
        results = list(executor.map(change_single, ips))
    
    return jsonify(results)

@app.route('/api/command/bulk/restart-browser', methods=['POST'])
def bulk_restart_browser():
    """Restart browser on multiple Pis"""
    data = request.get_json()
    ips = data.get('ips', [])
    
    def restart_single(ip):
        try:
            response = requests.post(f"http://{ip}:5000/restart-browser", timeout=10)
            return {'ip': ip, 'success': True}
        except Exception as e:
            return {'ip': ip, 'success': False, 'error': str(e)}
    
    with ThreadPoolExecutor(max_workers=10) as executor:
        results = list(executor.map(restart_single, ips))
    
    return jsonify(results)

if __name__ == '__main__':
    # Create empty config if it doesn't exist
    if not os.path.exists(CONFIG_FILE):
        save_pis([])
    
    print("=" * 60)
    print("Pi Dashboard Server Starting")
    print("=" * 60)
    print("\nAccess the dashboard at: http://localhost:8080")
    print("\nMake sure all Pi agents are running on port 5000")
    print("=" * 60)
    
    app.run(host='0.0.0.0', port=8080, debug=True)
