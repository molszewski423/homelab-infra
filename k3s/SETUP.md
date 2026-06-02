# k3s Cluster - MikePC + archbox + MikeInspiron

**Updated:** 2026-06-01
**k3s version:** v1.35.5+k3s1
**Status:** Running - 3 nodes, LAN networking (flannel VXLAN over LAN)

> **2026-06-01:** Migrated from Tailscale-based flannel to LAN-based flannel.
> MikePC got a new Tailscale IP after Debian 13 migration, breaking cross-node VXLAN.
> Cluster now routes flannel traffic directly over the home LAN.

## Cluster

| Node | Role | LAN IP | OS | Kernel |
|---|---|---|---|---|
| mikepc | control-plane | 192.168.4.54 | Debian 13 | 6.12.90 |
| archbox | worker | 192.168.4.45 | Arch Linux | 7.0.10-arch1 |
| mikeinspiron | worker | 192.168.4.29 | Debian 13 | - |

## Install - Control Plane (MikePC, Debian 13)

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.4.54 --tls-san=192.168.4.54 --write-kubeconfig-mode=644" sh -
```

Or edit `/etc/systemd/system/k3s.service` directly:

```
ExecStart=/usr/local/bin/k3s \
    server \
    '--node-ip=192.168.4.54' \
    '--write-kubeconfig-mode=644' \
    '--tls-san=192.168.4.54' \
```

Get join token:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

## Install - Worker Node (archbox, Arch Linux)

Create `/etc/systemd/system/k3s-agent.service.env`:

```
K3S_URL=https://192.168.4.54:6443
K3S_TOKEN=<token from above>
```

Then:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent" sh -
sudo systemctl daemon-reload && sudo systemctl restart k3s-agent
```

## Gotcha - Podman + k8s Cloudflare Tunnel Conflict

archbox ran agency services as Podman quadlets before k8s migration.
The `agency-tunnel.service` Podman container survives k8s migration and competes
with the k8s tunnel pod for the same Cloudflare tunnel credentials → connection
cycling → 502s on ringcatch.io.

**Fix:** stop the systemd user service on archbox:

```bash
systemctl --user stop agency-tunnel.service
systemctl --user disable agency-tunnel.service
```

Check with: `ps aux | grep cloudflared` — should show exactly one process.

## Gotcha - Tailscale IP change breaks flannel VXLAN

If MikePC gets a new Tailscale IP (e.g. after OS reinstall), archbox's flannel
FDB still points to the old IP → cross-node pod networking breaks → CoreDNS
unreachable → services needing DNS at startup crashloop.

Symptoms: `dig @10.43.0.10 discord.com` times out from archbox host.

**Fix:**
1. Update `/etc/systemd/system/k3s.service` on MikePC — change `--node-ip`, remove `--flannel-iface=tailscale0`
2. Restart k3s: `sudo systemctl daemon-reload && sudo systemctl restart k3s`
3. Update flannel annotation: `kubectl annotate node mikepc flannel.alpha.coreos.com/public-ip=192.168.4.54 --overwrite`
4. archbox FDB updates automatically once server restarts

## Gotcha - iptables/nftables warning on Arch (non-fatal)

```
iptables-save v1.8.13 (nf_tables): Parsing nftables rule failed
```

Appears in k3s-agent logs on archbox but is harmless. Flannel VXLAN and pod
networking work correctly despite the warning.

## Gotcha - Token Line Break

When pasting the join token, long tokens can wrap and introduce a literal newline.
Fix by editing the env file directly:

```bash
sudo nano /etc/systemd/system/k3s-agent.service.env
sudo systemctl daemon-reload && sudo systemctl restart k3s-agent
```

## Node Labels

```bash
kubectl label node mikepc gpu=true
kubectl label node mikepc always-on=true
kubectl label node archbox always-on=true
```

## kubeconfig

kubeconfig is at `/etc/rancher/k3s/k3s.yaml` on MikePC. Copy to another machine:

```bash
scp mike@192.168.4.54:/etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i 's/127.0.0.1/192.168.4.54/g' ~/.kube/config
```

## Useful Commands

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl top nodes
sudo systemctl status k3s              # control plane (MikePC)
sudo systemctl status k3s-agent        # worker (archbox)
sudo journalctl -u k3s-agent -f
```
