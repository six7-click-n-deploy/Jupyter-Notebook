# OpenStack App: Jupyter Notebook (Multi-User)

Dieses Repository erstellt ein **Jupyter Notebook System** auf OpenStack mit sauberer Trennung von:
- **Packer**: baut ein wiederverwendbares **Image** mit JupyterHub
- **Terraform**: deployt **Infrastruktur** und **User/Groups** (eine gemeinsame VM)

**Wichtig:** Die Struktur und das User/Group-Handling sind identisch zu Ubuntu-App, aber die App ist JupyterHub.

---

## Struktur

```plaintext
jupyter-notebook/
├── packer/
│   ├── template.pkr.hcl          # Packer Template (Image Build)
│   ├── packer.pkrvars.hcl.example  # Beispiel-Variablen (kopieren/ausfüllen)
│   └── scripts/
│       └── provision.sh          # Provisioning (JupyterHub + JupyterLab)
│
├── terraform/
│   ├── main.tf                   # OpenStack Ressourcen (Shared VM + User)
│   ├── variables.tf              # Variablen
│   ├── outputs.tf                # Outputs
│   ├── cloud-init-multi-user.yml.tpl # User/Group + JupyterHub Start
│   └── terraform.tfvars.example  # Beispiel-Variablen (kopieren/ausfüllen)
│
├── .github/workflows/
│   └── terraform.yml             # GitHub Actions CI/CD
├── .gitignore
└── README.md
```

---

## Voraussetzungen

- **Packer** >= 1.9
- **Terraform** >= 1.5
- **OpenStack Zugang** (clouds.yaml oder OS_* env vars)
- Optional: **OpenStack CLI** (für Debug/Listen/Löschen)

### macOS (Homebrew)

```bash
brew install packer terraform python-openstackclient
```

---

## OpenStack Auth (lokal, nicht committen)

**Empfohlen: `clouds.yaml`**

Standardpfad:
```plaintext
~/.config/openstack/clouds.yaml
```

Beispiel:
```yaml
clouds:
  openstack:
    auth:
      auth_url: <AUTH_URL>
      username: "<USERNAME>"
      password: "<PASSWORD>"
      project_name: "<PROJECT_NAME>"
      user_domain_name: "<USER_DOMAIN_NAME>"
    region_name: "<REGION_NAME>"
    interface: "public"
    identity_api_version: 3
```

Rechte setzen:
```bash
chmod 600 ~/.config/openstack/clouds.yaml
```

Cloud auswählen:
```bash
export OS_CLOUD=openstack
```

Test:
```bash
openstack token issue
```

---

## Schritt 1: Repo als Template nutzen

### Option A: Template-Repo auf GitHub verwenden
"Use this template" → neues Repo anlegen

### Option B: Klonen
```bash
git clone <REPO_URL> my-project
cd my-project
```

---

## Schritt 2: Packer konfigurieren (Image Build)

### 2.1 Variablen setzen

**Option A: Beispiel-Datei kopieren (empfohlen)**
```bash
cd packer
cp packer.pkrvars.hcl.example packer.pkrvars.hcl
# -> packer.pkrvars.hcl mit deinen Werten ausfüllen
```

**Option B: Direkt in Kommandozeile**
```bash
packer build \
  -var image_name="my-app-image" \
  -var source_image_name="Ubuntu 22.04" \
  -var flavor="gp1.small" \
  -var 'networks=["network-uuid"]' \
  .
```

`packer.pkrvars.hcl` ist lokal/projekt-spezifisch und sollte nicht committet werden.

**Typische Werte, die du setzen musst:**
- `image_name` - Name deines Output-Images (z.B. `jupyter-notebook-v1`)
- `networks` - Liste der Netzwerk-UUIDs für Build-VM
- `security_groups` - Security Group für Build-VM

### 2.2 Provisioning anpassen

**Datei:** `packer/scripts/provision.sh`

Dieses Script installiert:
- JupyterHub + JupyterLab
- systemd-Service
- Basis-Tools

Es ist idempotent und für CI/CD geeignet.

---

## Schritt 3: Image bauen

Im `packer/` Ordner:
```bash
packer init .
packer validate -var-file=packer.pkrvars.hcl .
packer build -var-file=packer.pkrvars.hcl .
```

**Ergebnis:**
- Neues Image erscheint in OpenStack (Glance)
- Image-Name entspricht `image_name` (wird später in Terraform verwendet)

---

## Schritt 4: Terraform konfigurieren (Deployment)

Wechsel in den Ordner `terraform/`:
```bash
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` ist lokal/projekt-spezifisch und sollte nicht committet werden.

**Typische Werte, die du setzen musst:**
- `image_name` (muss zum Packer-Output passen)
- `network_uuid`
- optional: `floating_ip_pool`
- `shared_secgroup_id` (muss Port 8000 und SSH erlauben)
- `users` (Teams mit User-Emails)

---

## Schritt 5: Infrastruktur deployen

```bash
terraform init
terraform plan
terraform apply
```

**Nach apply bekommst du Outputs wie:**
- `user_accounts` (JupyterHub Logins)
- `vm_details` (IP + Jupyter URL)
- `users_summary`

---

## Was muss ich wann tun?

| Änderung | Was tun? |
|----------|----------|
| `packer/scripts/provision.sh` | `packer build ...` |
| `packer/template.pkr.hcl` | `packer build ...` |
| Terraform .tf Dateien | `terraform apply` |
| Ports (Security Group) | `terraform apply` |
| Neues Image verwenden | `packer build ...` + `terraform apply` |

---

## Cleanup

### Infrastruktur entfernen
```bash
cd terraform
terraform destroy
```

### Image entfernen (optional)
```bash
openstack image list
openstack image delete <IMAGE_ID>
```

---

## Troubleshooting (kurz)

### Packer kommt nicht per SSH auf die Build-VM
- `security_groups` in Packer müssen SSH erlauben (von deinem Runner/Bastion)
- Wenn Build-VM nur intern erreichbar: Runner muss im selben Netz sein oder
- `use_floating_ip=true` + `floating_ip_pool` setzen

### VM ist deployed, aber JupyterHub nicht erreichbar
- Security Group muss Port **8000/TCP** erlauben
- Service prüfen: `systemctl status jupyterhub`
- ggf. `enable_floating_ip=false` → dann nur intern erreichbar (private IP)

---

## GitHub Actions CI/CD (optional)

Das Template enthält eine GitHub Actions Workflow-Datei für automatisierte Deployments.

**Datei:** `.github/workflows/terraform.yml`

**Setup:**
1. Repository Secrets setzen:
   - `OPENSTACK_CLOUDS_YAML` (Base64-encoded clouds.yaml)
   - Oder einzelne Secrets: `OS_AUTH_URL`, `OS_USERNAME`, etc.

2. Workflow wird getriggert bei:
   - Push auf `main` Branch
   - Pull Requests
   - Manuell über GitHub UI

---

## Minimaler Quickstart

```bash
# 1) Auth
export OS_CLOUD=openstack

# 2) Image bauen
cd packer
cp packer.pkrvars.hcl.example packer.pkrvars.hcl
# -> packer.pkrvars.hcl ausfüllen
# -> provision.sh ist bereits für JupyterHub vorbereitet
packer init .
packer build -var-file=packer.pkrvars.hcl .

# 3) Deploy
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
# -> terraform.tfvars ausfüllen (image_name + users)
terraform init
terraform apply
```

---

## Best Practices

### Sicherheit
- **Secrets niemals hardcoden**: Nutze Umgebungsvariablen, Vault oder Cloud-Init
- **SSH-Zugriff beschränken**: Setze `ssh_cidr` auf deine spezifische IP statt `0.0.0.0/0`
- **Security Groups minimalistisch**: Nur benötigte Ports öffnen

### Entwicklung
- **Idempotenz**: `provision.sh` muss mehrfach ausführbar sein
- **Versionierung**: Nutze semantische Versionierung für Image-Namen
- **Testing**: Teste Image-Builds in separater Umgebung

### Operations
- **Monitoring**: Überwache JupyterHub-Logs und Service-Status
- **Logs**: Nutze strukturierte Logs für bessere Auswertung
- **Backups**: Plane Backup-Strategien für persistente Daten