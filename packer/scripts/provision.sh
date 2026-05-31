#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Jupyter Notebook / JupyterHub Provisioning Script
# - Mehrbenutzer-Betrieb via JupyterHub (PAM + System-User)
# - Idempotent, reproduzierbar, CI/CD-tauglich
# -----------------------------------------------------------------------------

echo "Warte auf cloud-init (sofern vorhanden)..."
cloud-init status --wait || true

echo "System aktualisieren..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

echo "Installiere Basis-Pakete..."
sudo apt-get install -y --no-install-recommends \
  curl ca-certificates git \
  python3 python3-venv python3-pip \
  nodejs npm

# SSH-Passwort-Authentifizierung vorbereiten (für cloud-init)
echo "Bereite SSH für Passwort-Auth vor..."
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

echo "Installiere JupyterHub + JupyterLab..."
if [ ! -d "/opt/jupyterhub" ]; then
  sudo python3 -m venv /opt/jupyterhub
fi

sudo /opt/jupyterhub/bin/pip install --upgrade pip
sudo /opt/jupyterhub/bin/pip install jupyterhub jupyterlab

echo "Installiere configurable-http-proxy..."
sudo npm install -g configurable-http-proxy

echo "Konfiguriere JupyterHub..."
sudo mkdir -p /etc/jupyterhub

sudo tee /etc/jupyterhub/jupyterhub_config.py >/dev/null << 'EOF'
c = get_config()
c.JupyterHub.bind_url = "http://0.0.0.0:8000"
c.JupyterHub.spawner_class = "jupyterhub.spawner.LocalProcessSpawner"
c.Spawner.default_url = "/lab"
c.Authenticator.admin_users = set()
EOF

echo "Systemd-Service für JupyterHub erstellen..."
sudo tee /etc/systemd/system/jupyterhub.service >/dev/null << 'EOF'
[Unit]
Description=JupyterHub
After=network.target

[Service]
Type=simple
ExecStart=/opt/jupyterhub/bin/jupyterhub -f /etc/jupyterhub/jupyterhub_config.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable jupyterhub
sudo systemctl restart jupyterhub

echo "Cleanup: apt-Cache & Listen entfernen..."
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

echo "Setze machine-id zurück..."
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id || true

echo "Provisioning abgeschlossen."
