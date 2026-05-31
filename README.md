# homelab-infra

Infrastructure as Code for a three-node k3s homelab running a 24-service AI agency platform and a local clinical AI platform.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    k3s Cluster (LAN: 192.168.4.x)               │
│                                                                  │
│  ┌──────────────────────┐   ┌──────────────────────────────┐    │
│  │       mikepc          │   │           archbox            │    │
│  │  (control plane+GPU)  │   │          (worker)            │    │
│  │  192.168.4.54         │   │  192.168.4.46                │    │
│  │  RTX 5060 Ti 16GB     │   │  Intel i3-4130T, 24/7        │    │
│  │                       │   │                              │    │
│  │  namespace: ai        │   │  namespace: agency           │    │
│  │  ┌─────────────────┐  │   │  ┌──────────────────────┐   │    │
│  │  │ ollama (GPU)    │  │   │  │ 24 agency services   │   │    │
│  │  │ pv-workbench    │  │   │  │ PostgreSQL           │   │    │
│  │  │ ams-intelligence│  │   │  │ n8n · Cal.com        │   │    │
│  │  │ argus-bot       │  │   │  │ Cloudflare tunnel    │   │    │
│  │  └─────────────────┘  │   │  └──────────────────────┘   │    │
│  └──────────────────────┘   └──────────────────────────────┘    │
│                                                                  │
│  ┌──────────────────────┐                                        │
│  │    mikeinspiron       │                                        │
│  │    (worker)           │                                        │
│  │    192.168.4.33       │                                        │
│  │    Dell Inspiron,     │                                        │
│  │    24/7 lid-closed    │                                        │
│  └──────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
              Cloudflare Tunnel (no open ports)
                              │
              ┌───────────────┴────────────────┐
              │                                │
         ringcatch.io                  dashboard.ringcatch.io
         (agency-landing)              (agency-command)
```

---

## Nodes

| Node | Role | LAN IP | Tailscale IP | Hardware | OS |
|---|---|---|---|---|---|
| **mikepc** | Control plane + GPU | 192.168.4.54 | 100.97.45.57 | RTX 5060 Ti 16 GB, 32 GB RAM | Debian 13 |
| **archbox** | Worker | 192.168.4.46 | 100.96.122.27 | Intel i3-4130T, 24/7 server | Arch Linux |
| **mikeinspiron** | Worker | 192.168.4.33 | - (LAN only) | Dell Inspiron, 24/7 lid-closed | Debian 13 |

All nodes on the same LAN. kubectl must be run from **mikepc** (control plane).

---

## Namespaces

### `ai` - Clinical AI Platform (all pods pinned to mikepc)

| Deployment | Image | Access |
|---|---|---|
| `ollama` | `ollama/ollama:latest` | `http://ollama:11434` (in-cluster) |
| `pv-workbench` | `registry.gitlab.com/molszewski423/pv-workbench:latest` | http://pv.lan |
| `ams-intelligence` | `registry.gitlab.com/molszewski423/ams-intelligence:latest` | http://ams.lan |
| `argus-bot` | `registry.gitlab.com/molszewski423/pv-workbench:latest` | Discord (Argus#1432) |

Ollama models: `gemma4:26b` · `gemma4:e4b` · `qwen3:30b` · `qwen2.5:7b` · `nomic-embed-text`

DNS for `ai` apps - add to `/etc/hosts` on each machine:
```
192.168.4.54  pv.lan ams.lan
```

### `agency` - RingCatch AI Agency (all pods pinned to archbox)

24 services migrated from Podman quadlets to k3s on 2026-05-31.

| Service | Port | Purpose |
|---|---|---|
| agency-orchestrator | 8109 | AI brain - FastAPI, 22 tools |
| agency-outreach | 8080 | Email sending + /book sales chat (Alex persona) |
| agency-scraper | 8079 | Google Maps lead scraper |
| agency-command | 8100 | Dashboard / command center |
| agency-landing | 80 (nginx on 8090) | ringcatch.io public site |
| agency-discord | 8103 | Discord bot bridge |
| agency-billing | 8082 | Billing service |
| agency-legal | 8101 | Legal service |
| agency-marketing | 8102 | Marketing service |
| agency-support | 8104 | Tech support monitor |
| agency-success | 8105 | Customer success |
| agency-bi | 8106 | Business intelligence |
| agency-sales | 8107 | Sales service |
| agency-cfo | 8108 | CFO service |
| agency-inbox | 8110 | Email inbox monitor |
| agency-delivery | 8081 | Email delivery |
| agency-video | 8111 | YouTube Short generation |
| agency-dashboard | 8501 | Internal dashboard |
| agency-postgres | 5432 | PostgreSQL 16 (stateful PVC) |
| agency-n8n | 5678 | n8n workflow automation |
| agency-calcom | 3000 | Cal.com booking |
| agency-kokoro | 8080 | Kokoro TTS |
| agency-voice | 8000 | Speaches voice service |
| agency-tunnel | - | Cloudflare tunnel (outbound only) |

Public access via Cloudflare tunnel (no open ports):
- `ringcatch.io` → `http://agency-landing:80`
- `dashboard.ringcatch.io` → `http://agency-command:8100`

---

## Repository Structure

```
homelab-infra/
├── k8s/
│   ├── agency.yaml          # All 24 agency Deployments + Services + PVCs
│   ├── ollama.yaml          # Ollama GPU pod
│   ├── pv-workbench.yaml    # PV Workbench + PVCs
│   ├── ams-intelligence.yaml
│   ├── argus.yaml           # Argus Discord bot
│   └── ingress.yaml         # Traefik ingress rules (pv.lan, ams.lan)
├── quadlets/                # Legacy Podman quadlets (archived, superseded by k8s/)
├── scripts/                 # Cloudflare tunnel setup, backup scripts
└── docs/
    └── architecture.png
```

---

## Operations

### Deploy / update a service

```bash
# Clinical AI (images from GitLab registry)
kubectl rollout restart deployment/pv-workbench -n ai
kubectl rollout restart deployment/ams-intelligence -n ai

# Agency (custom images - must rebuild and reimport on archbox)
# 1. Edit code on archbox
# 2. cd ~/agency/<service> && podman build -t localhost/agency-<service>:latest .
# 3. podman save localhost/agency-<service>:latest | sudo k3s ctr -n k8s.io images import -
# 4. kubectl rollout restart deployment/agency-<service> -n agency
```

### Check cluster health

```bash
kubectl get nodes
kubectl get pods -n ai
kubectl get pods -n agency
```

### Secrets

```bash
# Registry pull secret (ai namespace - clinical AI images)
kubectl create secret docker-registry gitlab-registry -n ai \
  --docker-server=registry.gitlab.com \
  --docker-username=<user> \
  --docker-password=<pat-read-registry>

# Agency secrets (from ~/agency/.env on archbox - never commit)
kubectl create secret generic agency-env -n agency \
  --from-env-file=/home/mike/agency/.env
```

### LLM routing

All LLM inference runs on the **Ollama k3s pod** on mikepc (RTX 5060 Ti):
- From `ai` namespace: `http://ollama:11434`
- From `agency` namespace or archbox host: `http://100.97.45.57:11434`

---

## Migration history

| Date | Change |
|---|---|
| 2026-05-31 | k3s cluster created (mikepc + archbox) |
| 2026-05-31 | Ollama migrated from systemd service → k3s GPU pod |
| 2026-05-31 | pv-workbench, ams-intelligence, argus-bot deployed to k3s |
| 2026-05-31 | RingCatch agency migrated from Podman quadlets → k3s (24 services) |
| 2026-05-31 | mikeinspiron joined cluster as 3rd worker node |
