# k3s Cluster

Two-node Kubernetes cluster over Tailscale WireGuard mesh.
No open ports required - all node communication over encrypted Tailscale tunnel.

## Nodes

| Node | Role | Tailscale IP | OS |
|---|---|---|---|
| mikepc | control-plane + worker | 100.97.45.57 | Debian 13 |
| archbox | worker | 100.96.122.27 | Arch Linux |
| MikeInspiron | worker (pending) | 192.168.4.29 | Debian 13 |

## Node Labels

- `gpu=true` - MikePC (RTX 5060 Ti 16GB) - AI inference workloads
- `always-on=true` - MikePC + archbox - long-running services

## Setup

See `SETUP.md` for full installation guide including gotchas.

## Manifests

`manifests/` - Kubernetes workload definitions.
All workloads use nodeSelector to control placement.

## Future

- MikeInspiron as third worker node
- NVIDIA GPU operator for RTX 5060 Ti
- Agency services migrated from Podman quadlets
- AWS EKS path - same manifests, cloud node pool added
