#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# TEMPLATE Provisioning Script
# Ziel: Hier kommt *deine* App/Runtime rein.
#
# Regeln:
# - idempotent schreiben (mehrfaches Ausführen darf nicht kaputt machen)
# - keine Secrets hardcoden (nutze CI, Vault, cloud-init, env vars, etc.)
# - am Ende: Service läuft / Artefakte liegen / Ports passen zur SG
# -----------------------------------------------------------------------------

echo "Waiting for cloud-init (if present)..."
cloud-init status --wait || true

# Baseline (optional):
# - Updates / Base-Pakete
# - Logs/Debug
echo "Updating package lists..."
sudo apt-get update

# -----------------------------------------------------------------------------
# [1] Runtime installieren: minimaler Webserver (nginx)
# -----------------------------------------------------------------------------
echo "Installing nginx (if not already installed)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

echo "Enabling and restarting nginx..."
sudo systemctl enable nginx
sudo systemctl restart nginx

# -----------------------------------------------------------------------------
# [2] App-Artefakt: einfache HTML-Seite
# -----------------------------------------------------------------------------
echo "Deploying simple index.html..."
sudo mkdir -p /var/www/html

sudo tee /var/www/html/index.html >/dev/null << 'EOF'
<html>
  <head>
    <title>myapp2</title>
  </head>
  <body>
    <h1>Hello from myapp2!</h1>
    <p>Built with Packer & deployed with Terraform.</p>
  </body>
</html>
EOF

# -----------------------------------------------------------------------------
# [3] (Optional) eigener systemd-Service
# - hier nicht nötig, nginx reicht als Webserver
# -----------------------------------------------------------------------------
# Beispiel bleibt auskommentiert

# -----------------------------------------------------------------------------
# [4] Optional: Reverse Proxy / TLS / Firewall
# - für das Minimal-Beispiel nicht nötig
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# [5] Cleanup (optional, wenn du kleinere Images willst)
# -----------------------------------------------------------------------------
# sudo apt-get clean
# sudo rm -rf /var/lib/apt/lists/*

echo "Provisioning finished."
