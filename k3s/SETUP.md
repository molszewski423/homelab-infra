# k3s Cluster - mikepc + archbox + centosbook

**Updated:** 2026-07-25
**k3s version:** v1.36.2+k3s1 (auto-tracked via system-upgrade-controller, stable channel)
**Status:** Running - 3 nodes, LAN networking (flannel VXLAN over LAN)

> **2026-06-01:** Migrated from Tailscale-based flannel to LAN-based flannel.
> MikePC got a new Tailscale IP after Debian 13 migration, breaking cross-node VXLAN.
> Cluster now routes flannel traffic directly over the home LAN.

> **2026-07-25:** `MikeInspiron` (Debian 13, listed as "pending" worker) was reimaged
> to CentOS Stream 10 and rejoined as node `centosbook`. k3s upgraded to v1.36.2+k3s1
> across all nodes via `system-upgrade-controller` Plans (`k3s-server`/`k3s-agent`,
> stable channel) — check status with `kubectl get plans -n system-upgrade`.

## Cluster

| Node | Role | LAN IP | OS | Kernel |
|---|---|---|---|---|
| mikepc | control-plane | 192.168.4.54 | Debian 13 | 6.12.95+deb13 |
| archbox | worker | 192.168.4.45 | Arch Linux | 7.0.10-arch1 |
| centosbook | worker | 192.168.4.33 | CentOS Stream 10 | 6.12.0-250.el10 |

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

## Install - Worker Node (centosbook, CentOS Stream 10)

Same join steps as above (`K3S_URL`/`K3S_TOKEN` in `/etc/systemd/system/k3s-agent.service.env`,
then `curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent" sh -`).

**Lid-close suspend:** confirmed handled via `/etc/systemd/logind.conf.d/10-no-lid-suspend.conf`
(`HandleLidSwitch=ignore` for battery/AC/docked) — already present after the reimage, no
action needed. `systemctl is-enabled` on the sleep/suspend/hibernate targets themselves
reports `static` (expected; logind's `HandleLidSwitch` is the actual gate, not unit masking).

## Gotcha - Tailscale overwrites resolv.conf on new nodes, breaks any pod scheduled there

Tailscale on Linux rewrites `/etc/resolv.conf` to point at its own MagicDNS resolver
(`100.100.100.100` / `fd7a:...::53`) by default. If a DNS-sensitive singleton pod with no
nodeSelector (CoreDNS, in this case) gets scheduled onto a node running Tailscale, it inherits
that resolv.conf via the `forward` plugin — and if MagicDNS isn't reachable from the pod
netns, **every DNS lookup cluster-wide fails**, including the Cloudflare tunnel's own lookups
(precheck fails, `agency-tunnel` crashloops, ringcatch.io 502s).

Symptoms in `kubectl logs -n kube-system -l k8s-app=kube-dns`:
```
[ERROR] plugin/errors: ... dial udp [fd7a:...::53]:53: connect: network is unreachable
```

**Fix (per node running Tailscale that might host CoreDNS):**
```bash
sudo tailscale set --accept-dns=false
kubectl rollout restart deployment/coredns -n kube-system
```
Hit this on centosbook 2026-07-25, first time a Tailscale-enabled node joined without a
nodeSelector excluding it from `kube-system` singletons.

## Gotcha - firewalld on CentOS drops forwarded pod/service traffic by default

Unlike archbox (Arch, no firewalld) and mikepc (Debian, no firewalld), CentOS Stream ships
`firewalld` active out of the box. Its default `public` zone only covers the physical NIC —
the `flannel.1`/`cni0` overlay interfaces aren't zone members, so traffic *forwarded* through
the node from other nodes gets silently dropped even though `firewall-cmd --list-all` shows
the flannel VXLAN port (8472/udp) and kubelet (10250/tcp) already open. This is what turned
the CoreDNS-on-centosbook incident above into a full outage — archbox couldn't reach the
CoreDNS pod's IP on centosbook's pod subnet at all ("no route to host"), despite the port
being open and ICMP to the node itself working fine.

**Fix:** trust the k3s pod and service CIDRs as sources, instead of touching the per-port
rules or the SSH/cockpit protections on the physical interface:
```bash
sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16   # pod CIDR
sudo firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16   # service CIDR
sudo firewall-cmd --reload
```
Do this on any future CentOS/RHEL-family node before relying on it for cluster-critical pods.

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
kubectl label node centosbook always-on=true
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
