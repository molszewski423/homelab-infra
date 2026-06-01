# homelab-infra

Infrastructure as Code for a three-node k3s homelab running a local clinical AI platform and a 24-service AI agency stack.

**k3s v1.35.5** - single control plane on mikepc, two workers (archbox + mikeinspiron), all on LAN 192.168.4.x. All manifests in `k8s/`. kubectl runs from mikepc only.

---

## Cluster Architecture

![Architecture](docs/cluster-architecture.png)



---

## Nodes

| Node | Role | LAN IP | Tailscale IP | Hardware | OS |
|---|---|---|---|---|---|
| **mikepc** | Control plane | 192.168.4.54 | 100.97.45.57 | RTX 5060 Ti 16 GB, 32 GB RAM | Debian 13 |
| **archbox** | Worker | 192.168.4.46 | 100.96.122.27 | Intel i3-4130T, 24/7 | Arch Linux |
| **mikeinspiron** | Worker | 192.168.4.33 | - (LAN only) | Dell Inspiron | Debian 13 |

kubectl must be run from **mikepc** (control plane). Worker nodes do not have kubectl configured.

---

## k3s Setup

### Installation

```fish
# Control plane (mikepc)
curl -sfL https://get.k3s.io | sh -

# Get node token for workers
sudo cat /var/lib/rancher/k3s/server/node-token

# Workers (archbox, mikeinspiron) - replace TOKEN
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.4.54:6443 K3S_TOKEN=<token> sh -
```

### kubeconfig

k3s writes the cluster admin config to `/etc/rancher/k3s/k3s.yaml`. Copy to user config and lock down the original:

```fish
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown mike:mike ~/.kube/config
chmod 600 ~/.kube/config
sudo chmod 600 /etc/rancher/k3s/k3s.yaml

# Add to fish config so kubectl uses the user copy
echo 'set -x KUBECONFIG $HOME/.kube/config' >> ~/.config/fish/config.fish
```

### Storage

k3s ships the **local-path provisioner** as the default StorageClass. PVCs use hostPath storage on the node they're scheduled to - data is local to that node, not replicated.

```
NAME                   PROVISIONER             RECLAIMPOLICY
local-path (default)   rancher.io/local-path   Delete
```

Stateful workloads (Postgres, ChromaDB, Ollama models, Gitea data) all use local-path PVCs pinned to their node via `nodeSelector`.

### Networking

k3s uses **Flannel** (VXLAN) as the CNI and ships **Traefik** as the default ingress controller. All nodes are on the same LAN - no overlay network needed for intra-cluster traffic.

```
Pod CIDR:     10.42.0.0/16
Service CIDR: 10.43.0.0/16
```

LAN DNS for `ai` and `infra` apps - add to `/etc/hosts` on each machine:
```
192.168.4.54  pv.lan ams.lan git.lan
```

### GPU (NVIDIA RTX 5060 Ti on mikepc)

Ollama runs as a GPU pod using the NVIDIA device plugin:

```fish
# Install NVIDIA device plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.0/deployments/static/nvidia-device-plugin.yml

# Verify GPU is visible
kubectl describe node mikepc | grep nvidia
```

The Ollama deployment (`k8s/ollama.yaml`) pins to mikepc and requests the GPU:
```yaml
nodeSelector:
  kubernetes.io/hostname: mikepc
runtimeClassName: nvidia
resources:
  limits:
    nvidia.com/gpu: 1
```

---

## Namespaces

### `ai` - Clinical AI (all pods pinned to mikepc)

| Deployment | Image | Exposed at |
|---|---|---|
| `ollama` | `ollama/ollama:latest` | `http://ollama:11434` (in-cluster) |
| `pv-workbench` | `registry.gitlab.com/molszewski423/pv-workbench:latest` | http://pv.lan |
| `ams-intelligence` | `registry.gitlab.com/molszewski423/ams-intelligence:latest` | http://ams.lan |
| `argus-bot` | `registry.gitlab.com/molszewski423/pv-workbench:latest` | Discord (Argus#1432) |

Ollama models loaded: `gemma4:26b` · `gemma4:e4b` · `qwen3:30b` · `qwen2.5:7b` · `nomic-embed-text`

### `agency` - RingCatch AI Agency (all pods pinned to archbox)

24 services. Custom images are `localhost/agency-*:latest` - built with Podman on archbox and imported into k3s containerd directly (not in any registry).

See [ringcatch-agency](https://gitlab.com/molszewski423/ringcatch-agency) for the full service list, LLM routing chain, and rebuild workflow.

### `infra` - Self-hosted Git

| Deployment | Exposed at |
|---|---|
| `gitea` | http://git.lan |

Gitea push-mirrors all repos to GitLab on every commit.

---

## Repository Structure

```
k8s/
├── ollama.yaml            # GPU pod + PV + PVC + Service
├── pv-workbench.yaml      # Streamlit app + PVCs (chroma, output)
├── ams-intelligence.yaml  # Streamlit app + PVCs (chroma, output, data)
├── argus.yaml             # Discord bot (same image as pv-workbench)
├── ingress.yaml           # Traefik IngressRoutes: pv.lan, ams.lan, git.lan
├── gitea.yaml             # Gitea + PVC
└── agency.yaml            # All 24 agency Deployments + Services + PVCs
```

---

## Operations

### Deploy / update

```fish
# Apply all manifests from mikepc
kubectl apply -f ~/homelab-infra/k8s/

# Restart after image update (ai namespace - pulls from GitLab registry)
kubectl rollout restart deployment/pv-workbench -n ai
kubectl rollout restart deployment/ams-intelligence -n ai

# Agency services - rebuild + reimport on archbox first, then restart from mikepc
# On archbox:
cd ~/agency/<service>
podman build -t localhost/agency-<service>:latest .
podman save localhost/agency-<service>:latest | sudo k3s ctr -n k8s.io images import -
# From mikepc:
kubectl rollout restart deployment/agency-<service> -n agency
```

### Cluster health

```fish
kubectl get nodes
kubectl get pods -n ai
kubectl get pods -n agency
kubectl get pods -n infra
kubectl get pvc --all-namespaces
```

### Secrets

```fish
# GitLab registry pull secret (ai namespace - for pulling clinical AI images)
kubectl create secret docker-registry gitlab-registry -n ai \
  --docker-server=registry.gitlab.com \
  --docker-username=<user> \
  --docker-password=<pat-read-registry>

# Agency env (sourced from ~/agency/.env on archbox - never commit)
kubectl create secret generic agency-env -n agency \
  --from-env-file=/home/mike/agency/.env
```

---

## Migration History

| Date | Event |
|---|---|
| 2026-05-31 | k3s cluster created: mikepc (control plane) + archbox (worker) |
| 2026-05-31 | Ollama migrated from systemd service to k3s GPU pod |
| 2026-05-31 | pv-workbench, ams-intelligence, argus-bot deployed to k3s |
| 2026-05-31 | RingCatch agency migrated from Podman quadlets to k3s (24 services) |
| 2026-05-31 | mikeinspiron joined as 3rd worker node |
| 2026-05-31 | kubeconfig locked down: k3s.yaml chmod 600, user copy at ~/.kube/config |
