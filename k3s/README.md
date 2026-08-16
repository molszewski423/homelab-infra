# k3s Cluster

Three-node Kubernetes cluster over the home LAN (flannel VXLAN on LAN IPs).
Migrated off Tailscale-based flannel 2026-06-01 — see SETUP.md gotcha.

## Nodes

| Node | Role | LAN IP | Tailscale IP | OS |
|---|---|---|---|---|
| mikepc | control-plane + worker | 192.168.4.54 | 100.97.45.57 | Debian 13 |
| debianbox | worker | 192.168.4.45 | 100.80.218.77 | Debian 13 |
| centosbook | worker | 192.168.4.33 | — | CentOS Stream 10 |

`debianbox` was `archbox` (Arch Linux) until 2026-07-26, when its last Arch update broke
reboot reliability and it was wiped and reinstalled as Debian 13 — same LAN IP, new
Tailscale IP (old archbox's 100.96.122.27 is retired). Real hostname/k3s node rename, not
a nickname; the old `archbox` node object was deleted from the cluster and a fresh
`debianbox` node joined in its place. hostPath PV data (agency-postgres/n8n/data/voice)
and the local-path Prometheus/Grafana volumes were restored from a pre-wipe backup; all
custom `agency-*` container images had to be rebuilt from source since they only ever
existed in the old box's local containerd store.

`centosbook` is the same physical Inspiron laptop that was previously `MikeInspiron`
(Debian 13, never fully joined). Reimaged to CentOS Stream 10 and joined 2026-07-25.
Lid-closed 24/7 like its predecessor — `/etc/systemd/logind.conf.d/10-no-lid-suspend.conf`
sets `HandleLidSwitch=ignore` (battery/AC/docked), confirmed present after the reimage.

### OS diversity (was deliberate, now reduced by the 2026-07-26 rebuild)

The cluster was originally intentionally multi-distro (Debian on mikepc, Arch on archbox,
CentOS Stream on centosbook) specifically to force workload manifests and setup docs to
stay distro-agnostic and catch package/systemd-unit/firewall-tooling assumptions the
other nodes' similarity would hide. **As of the 2026-07-26 archbox→debianbox rebuild,
that's now Debian+Debian+CentOS** — two of three nodes match, so this property is
weaker than originally designed. Worth keeping in mind before assuming manifests are
still being exercised against genuinely different package managers on every node.

centosbook still doubles as a standing RHEL-family environment for tracking Fedora/CentOS
Stream (upstream of RHEL) changes, testing/reporting bugs, and general RHEL ecosystem
familiarity — separate from its role as cluster capacity. It also concretely surfaced a
real difference on day one: CentOS ships `firewalld` instead of `nftables`/`iptables` —
see the worker install section in SETUP.md.

## Node Labels

- `gpu=true` - mikepc (RTX 5060 Ti 16GB) - AI inference workloads
- `always-on=true` - mikepc + debianbox + centosbook - long-running/trusted for pinned services

## Setup

See `SETUP.md` for full installation guide including gotchas.

## Manifests

`k8s/` - Kubernetes workload definitions.
All workloads use nodeSelector to control placement.

## Constraints on node placement

Nearly every `agency-*` Deployment (all but `agency-landing`, `agency-calcom`,
`agency-kokoro`) mounts the shared `agency-data-pvc`, which is a `hostPath`-backed
PV with `nodeAffinity` locked to debianbox. `agency-postgres`, `agency-n8n`, and
`agency-voice` each have their own debianbox-pinned hostPath PVs too. None of these
can be moved to another node without first migrating that storage to something
node-agnostic (NFS export off debianbox, Longhorn, etc.) — until then, centosbook
can only host workloads with no dependency on that volume. This same hard-pinning is
exactly what made the 2026-07-26 archbox→debianbox rebuild high-risk: every one of
these PVs' `nodeAffinity` had to be manually rebuilt to point at the new node name
before any of those pods could reschedule.

## Future

- Migrate `agency-data-pvc` off local hostPath to shared/networked storage so
  agency-* workloads aren't all hard-pinned to debianbox
- NVIDIA GPU operator for RTX 5060 Ti
- AWS EKS path - same manifests, cloud node pool added
