#cloud-config

# SSH mit Passwort-Auth aktivieren
ssh_pwauth: true

# Pakete installieren (Basis-Tools)
packages:
  - curl
  - wget
  - git
  - htop
  - nano
  - vim
  - openssl
  - net-tools

# Gruppen für jedes Team erstellen
groups:
%{ for team in unique_teams ~}
  - ${team}
%{ endfor ~}

# Benutzer erstellen
users:
%{ for idx, user in all_users ~}
  - name: ${user.username}
    shell: /bin/bash
    sudo: ['ALL=(ALL) ALL']
    groups: ${user.team}
    lock_passwd: false
%{ endfor ~}

# SSH-Konfiguration in separate Datei
write_files:
  - path: /etc/ssh/sshd_config.d/99-custom.conf
    content: |
      PasswordAuthentication yes
      PubkeyAuthentication yes
      PermitRootLogin no
      UsePAM yes
    permissions: '0644'

# Setup-Befehle
runcmd:
  # Passwörter setzen (ungehashed)
%{ for idx, user in all_users ~}
  - echo '${user.username}:${passwords[idx]}' | chpasswd
%{ endfor ~}

  # SSH-Service neu starten
  - systemctl restart sshd

  # JupyterHub sicherstellen
  - systemctl enable jupyterhub
  - systemctl restart jupyterhub

  # Optional: Firewall
  - ufw --force enable
  - ufw allow OpenSSH
  - ufw allow 8000/tcp

  # Setup-Log (OHNE Passwörter aus Sicherheitsgründen)
  - |
    cat >> /var/log/setup-complete.log <<EOF
    ================================================
    Setup abgeschlossen: $(date)
    ================================================
    Teams: ${join(", ", unique_teams)}
    Benutzer erstellt: ${length(all_users)}
    JupyterHub: Port 8000
    ================================================
    EOF

# Abschlussnachricht
final_message: |
  ================================================
  JupyterHub Multi-User System bereit!
  ================================================
  Teams: ${join(", ", unique_teams)}
  Benutzer: ${length(all_users)}

  Zugriff: http://<vm-ip>:8000
  Login: <username> + Passwort (siehe Outputs)
  ================================================
