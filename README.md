# OpenStack Template: Packer (Image) + Terraform (Deployment)

Dieses Repository ist ein **Template** für OpenStack-Projekte mit sauberer Trennung von:
- **Packer**: baut ein wiederverwendbares **Image**
- **Terraform**: deployt **Infrastruktur** (VM, Security Group, optional Floating IP)

Es enthält **keine App**. Du füllst nur die Stellen aus, an denen du deine eigene Anwendung/Runtime ins Image bringst.

---

## Struktur

```plaintext
template-app/
├── packer/
│   ├── template.pkr.hcl          # Packer Template (Image Build)
│   ├── packer.pkrvars.hcl.example  # Beispiel-Variablen (kopieren/ausfüllen)
│   └── scripts/
│       └── provision.sh          # Provisioning Skeleton (DEIN Inhalt)
│
├── terraform/
│   ├── main.tf                   # OpenStack Ressourcen (VM, SG, FIP)
│   ├── variables.tf              # Variablen
│   ├── outputs.tf                # Outputs
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
- `image_name` - Name deines Output-Images
- `source_image_name` - Base-Image (z.B. "Ubuntu 22.04")
- `flavor` - VM-Größe für Build (z.B. "gp1.small")
- `networks` - Liste der Netzwerk-UUIDs für Build-VM
- optional: `security_groups`, `floating_ip_pool` (falls Build-VM extern erreichbar sein muss)

### 2.2 Provisioning anpassen (DEIN Inhalt)

**Datei:** `packer/scripts/provision.sh`

Hier definierst du, was ins Image kommt:
- Pakete/Runtime installieren
- App-Artefakte deployen (z.B. Binary, Container, Webapp)
- Konfiguration
- systemd Services
- (optional) Reverse Proxy / TLS

**Wichtig:**
- keine Secrets hardcoden
- idempotent schreiben (mehrfaches Ausführen sollte nicht kaputt machen)

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
- `instance_name`
- `image_name` (muss zum Packer-Output passen)
- `flavor`
- `key_pair`
- `network_uuid`
- `enable_floating_ip` (true/false)
- optional: `floating_ip_pool`
- `allowed_tcp_ports` (öffentliche Ports, z.B. [80, 443])
- `ssh_cidr` (am besten deine.ip/32)

---

## Schritt 5: Infrastruktur deployen

```bash
terraform init
terraform plan
terraform apply
```

**Nach apply bekommst du Outputs wie:**
- `instance_id`
- `private_ip`
- `floating_ip` (falls enabled)
- `access_url`

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

### VM ist deployed, aber Service nicht erreichbar
- `allowed_tcp_ports` in Terraform setzen (z.B. [80] oder [443])
- Service im Image läuft wirklich? (systemd status, logs, etc.)
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
# -> provision.sh mit eigener App füllen
packer init .
packer build -var-file=packer.pkrvars.hcl .

# 3) Deploy
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
# -> terraform.tfvars ausfüllen (image_name!)
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
- **Monitoring**: Implementiere Health-Checks in deiner App
- **Logs**: Nutze structured logging (JSON) für bessere Auswertung
- **Backups**: Plane Backup-Strategien für persistente Daten