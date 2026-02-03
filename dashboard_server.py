#!/usr/bin/env python3
from flask import Flask, render_template, request, jsonify
import requests
import json
import os

app = Flask(__name__)

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

@app.route('/')
def index():
    """Render the main dashboard page"""
    pis = load_pis()
    return render_template('dashboard.html', pis=pis)

@app.route('/api/pis', methods=['GET'])
def get_pis():
    """Get all registered Pis"""
    return jsonify(load_pis())

@app.route('/api/pis', methods=['POST'])
def add_pi():
    """Add a new Pi to the dashboard"""
    data = request.get_json()
    pis = load_pis()
    
    # Check if Pi already exists
    for pi in pis:
        if pi['ip'] == data['ip']:
            return jsonify({'success': False, 'error': 'Pi already exists'}), 400
    
    pis.append({
        'ip': data['ip'],
        'name': data.get('name', data['ip'])
    })
    save_pis(pis)
    return jsonify({'success': True})

@app.route('/api/pis/<ip>', methods=['DELETE'])
def remove_pi(ip):
    """Remove a Pi from the dashboard"""
    pis = load_pis()
    pis = [pi for pi in pis if pi['ip'] != ip]
    save_pis(pis)
    return jsonify({'success': True})

@app.route('/api/pis/<ip>/name', methods=['PUT'])
def update_pi_name(ip):
    """Update a Pi's name"""
    data = request.get_json()
    pis = load_pis()
    
    for pi in pis:
        if pi['ip'] == ip:
            pi['name'] = data.get('name', pi['name'])
            save_pis(pis)
            return jsonify({'success': True})
    
    return jsonify({'success': False, 'error': 'Pi not found'}), 404

@app.route('/api/pis/<ip>/status')
def get_pi_status(ip):
    """Get status of a specific Pi"""
    try:
        response = requests.get(f'http://{ip}:5000/status', timeout=5)
        return jsonify({
            'online': True,
            'status': response.json()
        })
    except Exception as e:
        return jsonify({
            'online': False,
            'error': str(e)
        })

@app.route('/api/pis/<ip>/url', methods=['POST'])
def change_pi_url(ip):
    """Change URL on a specific Pi"""
    data = request.get_json()
    try:
        response = requests.post(
            f'http://{ip}:5000/url',
            json={'url': data['url']},
            timeout=5
        )
        return jsonify(response.json())
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/pis/<ip>/restart-browser', methods=['POST'])
def restart_pi_browser(ip):
    """Restart browser on a specific Pi"""
    try:
        response = requests.post(f'http://{ip}:5000/restart-browser', timeout=5)
        return jsonify(response.json())
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/pis/<ip>/reboot', methods=['POST'])
def reboot_pi(ip):
    """Reboot a specific Pi"""
    try:
        response = requests.post(f'http://{ip}:5000/reboot', timeout=5)
        return jsonify(response.json())
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/bulk/url', methods=['POST'])
def bulk_change_url():
    """Change URL on multiple Pis"""
    data = request.get_json()
    results = []
    
    for ip in data['ips']:
        try:
            response = requests.post(
                f'http://{ip}:5000/url',
                json={'url': data['url']},
                timeout=5
            )
            results.append({'ip': ip, 'success': True})
        except Exception as e:
            results.append({'ip': ip, 'success': False, 'error': str(e)})
    
    return jsonify({'results': results})

@app.route('/api/bulk/restart-browser', methods=['POST'])
def bulk_restart_browser():
    """Restart browser on multiple Pis"""
    data = request.get_json()
    results = []
    
    for ip in data['ips']:
        try:
            response = requests.post(f'http://{ip}:5000/restart-browser', timeout=5)
            results.append({'ip': ip, 'success': True})
        except Exception as e:
            results.append({'ip': ip, 'success': False, 'error': str(e)})
    
    return jsonify({'results': results})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
