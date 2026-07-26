# Network Security

Multi-layer network security stack running on debianbox (Debian 13, Intel i3-4130T) —
was archbox (Arch Linux) on the same physical hardware until wiped and reinstalled
2026-07-26. Previously ran on a Raspberry Pi 4 before migrating to archbox/debianbox.
The 2026-07-26 rebuild restored AdGuard's config + data (4.5M+ historical query log
entries confirmed intact), CrowdSec's config (reinstalled fresh — its local SQLite
machine/bouncer registrations aren't portable across a wipe, only `/etc/crowdsec/`
config was restored on top of a clean install), and nftables. The nftables restore
initially came back under the name `ringcatch_firewall`, since that was the only table
actually captured in the backup — this was later renamed to `homelab` and rebuilt to
match mikepc's structure exactly (priority -10, FORWARD/OUTPUT policy accept), since it's
a whole-host firewall, not something RingCatch/k3s-specific, and the name was misleading.
See `../README.md`'s Network Security section for the full history and current ruleset.

## Stack Overview

| Layer | Tool | Purpose |
|---|---|---|
| DNS filtering | AdGuard Home | Network-wide ad/tracker blocking, DNS-over-HTTPS |
| Intrusion detection | CrowdSec | Threat detection from logs, community blocklists |
| Firewall | nftables + CrowdSec bouncer | Dynamic IP banning, default-drop policy |
| VPN mesh | Tailscale | Zero-config WireGuard, exit node for all devices |
| Tunneling | Cloudflare Tunnel | Exposes services publicly without open ports |

## AdGuard Home

DNS server running on port 53, admin UI on port 3000.

- Upstream DNS: Cloudflare DoH + Google DoH + TLS resolvers
- Load balancing across upstreams
- DNSSEC validation disabled (upstream handles it)
- Cache: 4MB, optimistic caching enabled
- Blocks: ads, trackers, malware domains

Config: `adguard/AdGuardHome.yaml`

## CrowdSec

Reads SSH logs, auth logs, and audit logs. Bans IPs automatically via nftables bouncer.

- SSH brute force detection (fast + slow + time-based)
- Integrates with CrowdSec community threat feed
- nftables bouncer enforces bans at kernel level (DROP, not REJECT)

Configs: `crowdsec/`

## nftables Firewall

Table `inet homelab`, INPUT default-drop (FORWARD/OUTPUT policy accept — this table only
restricts inbound). Only LAN/Tailscale traffic and established connections accepted
inbound; no bare "allow SSH" rule — SSH access comes for free from the LAN/Tailscale
subnet allows, same as every other LAN-only service.
CrowdSec bouncer inserts dynamic ban sets (`crowdsec` and `crowdsec6` tables) alongside it.

```
INPUT policy: DROP
- allow loopback
- allow established/related
- allow ICMP/ICMPv6
- allow Tailscale interface + handshake port
- allow LAN (192.168.4.0/22) + k3s pod/service CIDRs
FORWARD/OUTPUT policy: ACCEPT
```

Config: `/etc/nftables.conf` on each node (the repo's `nftables/nftables.conf` is Debian's
unused default template, not the real config — see the top of this file for why).

## Tailscale

Full mesh VPN across all machines. debianbox acts as exit node.
MagicDNS tailnet-wide nameserver points at debianbox's Tailscale IP (AdGuard runs there) —
if this ever points at a stale/dead IP after a future rebuild, every Tailscale-enabled
device loses DNS/internet tailnet-wide until the admin console DNS tab is corrected. This
exact failure mode happened during the 2026-07-26 archbox→debianbox rebuild.

| Machine | Tailscale IP | Role |
|---|---|---|
| debianbox | 100.80.218.77 | Server, exit node (was archbox @ 100.96.122.27, retired 2026-07-26) |
| mikepc | 100.97.45.57 | Dev workstation |
| debianbook | 100.116.53.100 | Chromebook |
| iPhone | 100.122.21.25 | Mobile |

## Cloudflare Tunnel

Zero-trust tunnel  -  no open inbound ports on the router.
Services exposed: ringcatch.io (landing), dashboard.ringcatch.io (command center).

Runs as a k3s Deployment (`agency-tunnel`, `hostNetwork: true`) as of 2026-06-14 —
**not** a Podman container; this doc predates the Podman→k3s migration on that point.
Actually scheduled on **centosbook**, not debianbox, so the public site survives a
debianbox outage. Manifest: `../k8s/agency.yaml`.

## Raspberry Pi → Archbox → debianbox

This entire stack was originally deployed on a Raspberry Pi 4 (4GB), then migrated to
archbox (i3-4130T) for:
- x86 compatibility (no ARM container headaches)
- More CPU headroom for CrowdSec + AdGuard under load
- Ability to run the full 25-container agency pod on the same machine (historical — Podman
  agency-pod was retired 2026-06-14, all agency services run in k3s now)

archbox itself was wiped and reinstalled as Debian 13 ("debianbox") 2026-07-26 after its
last Arch update broke reboot reliability — same hardware, same role, new OS and hostname.
