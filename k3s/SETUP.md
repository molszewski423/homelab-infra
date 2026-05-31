# k3s Cluster over Tailscale - MikePC + archbox

**Date:** 2026-05-31
**k3s version:** v1.35.5+k3s1
**Status:** Running - 2 nodes, cross-node networking verified

## Cluster

| Node | Role | IP | OS | Kernel |
|---|---|---|---|---|
| mikepc | control-plane + worker | 100.97.45.57 | Debian 13 | 6.12.90 |
| archbox | worker | 100.96.122.27 | Arch Linux | 7.0.10-arch1 |
| MikeInspiron | worker (pending) | 192.168.4.29 | Debian 13 | - |

All nodes communicate via Tailscale WireGuard mesh - no open ports required.

## Install - Control Plane (MikePC, Debian 13)

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=100.97.45.57 --flannel-iface=tailscale0 --write-kubeconfig-mode=644" sh -
```

Get join token after install:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

## Install - Worker Node (archbox, Arch Linux)

Fish shell syntax:

```fish
set -x K3S_URL "https://100.97.45.57:6443"
set -x K3S_TOKEN "<token from above>"
set -x INSTALL_K3S_EXEC "agent --node-ip=100.96.122.27 --flannel-iface=tailscale0"
curl -sfL https://get.k3s.io | sh -
```

## Gotcha - Token Line Break

When pasting the join token in a terminal, long tokens can wrap and introduce
a literal newline character. The service env file ends up with something like:

```
K3S_TOKEN=...::server:6370d677c8n 41a25399...
                              ^^^
                        newline became "n "
```

The agent logs show `not authorized` repeatedly. Fix by editing the env file directly:

```bash
sudo nano /etc/systemd/system/k3s-agent.service.env
# Paste the full token on a single line, no wrapping
sudo systemctl daemon-reload && sudo systemctl restart k3s-agent
```

## Gotcha - iptables-restore warning on Arch

On install, Arch shows:

```
iptables-restore: COMMIT expected at line 11
```

This is harmless - Arch uses nftables by default and the iptables compatibility
layer throws a warning. k3s works correctly despite it.

## Node Labels

```bash
kubectl label node mikepc gpu=true
kubectl label node mikepc always-on=true
kubectl label node archbox always-on=true
```

Use in pod specs to control placement:

```yaml
nodeSelector:
  gpu: "true"        # lands on MikePC - RTX 5060 Ti 16GB
  always-on: "true"  # lands on archbox - 24/7 uptime
```

## Verify Cross-Node Networking

```bash
# Deploy one pod per node
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-test
spec:
  selector:
    matchLabels:
      app: node-test
  template:
    metadata:
      labels:
        app: node-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
EOF

# Get pod IPs
kubectl get pods -o wide

# Test cross-node communication (replace IPs with actual pod IPs)
kubectl exec <pod-on-mikepc> -- wget -qO- http://<ip-of-pod-on-archbox>

# Clean up
kubectl delete daemonset node-test
```

## kubeconfig

kubeconfig is at `/etc/rancher/k3s/k3s.yaml` on MikePC.
Copy to laptop for remote management:

```bash
scp mikepc:/etc/rancher/k3s/k3s.yaml ~/.kube/config
# Replace 127.0.0.1 with MikePC Tailscale IP
sed -i 's/127.0.0.1/100.97.45.57/g' ~/.kube/config
```

## Useful Commands

```bash
kubectl get nodes -o wide              # cluster status
kubectl get pods -A -o wide            # all pods with node placement
kubectl describe node mikepc           # resource usage, labels, events
kubectl top nodes                      # CPU/memory (needs metrics-server)
sudo systemctl status k3s              # control plane status (MikePC)
sudo systemctl status k3s-agent        # worker status (archbox)
sudo journalctl -u k3s-agent -f        # live agent logs
```

## Next Steps

- Add MikeInspiron as third worker node
- Deploy first real workload (Ollama GPU inference pod on MikePC)
- Add NVIDIA GPU operator for RTX 5060 Ti passthrough
- Migrate agency services from Podman quadlets to k3s manifests
- AWS EKS - same manifests, cloud node pool added
