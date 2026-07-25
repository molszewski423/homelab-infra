# k3s Cluster

Three-node Kubernetes cluster over the home LAN (flannel VXLAN on LAN IPs).
Migrated off Tailscale-based flannel 2026-06-01 — see SETUP.md gotcha.

## Nodes

| Node | Role | LAN IP | OS |
|---|---|---|---|
| mikepc | control-plane + worker | 192.168.4.54 | Debian 13 |
| archbox | worker | 192.168.4.45 | Arch Linux |
| centosbook | worker | 192.168.4.33 | CentOS Stream 10 |

`centosbook` is the same physical Inspiron laptop that was previously `MikeInspiron`
(Debian 13, never fully joined). Reimaged to CentOS Stream 10 and joined 2026-07-25.
Lid-closed 24/7 like its predecessor — `/etc/systemd/logind.conf.d/10-no-lid-suspend.conf`
sets `HandleLidSwitch=ignore` (battery/AC/docked), confirmed present after the reimage.

## Node Labels

- `gpu=true` - mikepc (RTX 5060 Ti 16GB) - AI inference workloads
- `always-on=true` - mikepc + archbox + centosbook - long-running/trusted for pinned services

## Setup

See `SETUP.md` for full installation guide including gotchas.

## Manifests

`k8s/` - Kubernetes workload definitions.
All workloads use nodeSelector to control placement.

## Constraints on node placement

Nearly every `agency-*` Deployment (all but `agency-landing`, `agency-calcom`,
`agency-kokoro`) mounts the shared `agency-data-pvc`, which is a `hostPath`-backed
PV with `nodeAffinity` locked to archbox. `agency-postgres`, `agency-n8n`, and
`agency-voice` each have their own archbox-pinned hostPath PVs too. None of these
can be moved to another node without first migrating that storage to something
node-agnostic (NFS export off archbox, Longhorn, etc.) — until then, centosbook
can only host workloads with no dependency on that volume.

## Future

- Migrate `agency-data-pvc` off local hostPath to shared/networked storage so
  agency-* workloads aren't all hard-pinned to archbox
- NVIDIA GPU operator for RTX 5060 Ti
- AWS EKS path - same manifests, cloud node pool added
