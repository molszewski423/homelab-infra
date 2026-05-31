# Network Security

Multi-layer network security stack running on archbox (Arch Linux, Intel i3-4130T).
Previously ran on a Raspberry Pi 4 before migrating to archbox.

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

Default-drop policy. Only SSH and established connections accepted inbound.
CrowdSec bouncer inserts dynamic ban sets (`crowdsec` and `crowdsec6` tables).

```
input policy: DROP
- allow established/related
- allow loopback
- allow ICMP/ICMPv6
- allow SSH
- CrowdSec ban sets applied at priority -10
```

Config: `nftables/nftables.conf`

## Tailscale

Full mesh VPN across all machines. Archbox acts as exit node.

| Machine | Tailscale IP | Role |
|---|---|---|
| archbox | 100.96.122.27 | Server, exit node |
| mikepc | 100.97.45.57 | Dev workstation |
| debianbook | 100.116.53.100 | Chromebook |
| iPhone | 100.122.21.25 | Mobile |

## Cloudflare Tunnel

Zero-trust tunnel  -  no open inbound ports on the router.
Services exposed: ringcatch.io (landing), dashboard.ringcatch.io (command center).

Runs as a Podman container in the agency pod. Config: `../quadlets/agency-tunnel.container`

## Raspberry Pi → Archbox Migration

This entire stack was originally deployed on a Raspberry Pi 4 (4GB).
Migrated to archbox (i3-4130T) for:
- x86 compatibility (no ARM container headaches)
- More CPU headroom for CrowdSec + AdGuard under load
- Ability to run the full 25-container agency pod on the same machine
