# Ansible  -  Archbox Bootstrap (STALE — Arch/pacman only, not ported to debianbox)

**As of 2026-07-26, archbox was wiped and reinstalled as Debian 13 ("debianbox").** This
playbook and all its roles (`base`, `nftables`, `tailscale`, `podman`, `adguard`,
`crowdsec`) use the Ansible `pacman` module throughout and will fail immediately against
a Debian host. The 2026-07-26 rebuild was done manually (documented in
[[reference_debianbox]] in Claude Code memory), not via this playbook. Treat everything
below as historical reference for the old Arch setup until someone ports it to `apt`.

Automates full archbox setup from a fresh Arch Linux install.

## Requirements

Install Ansible on your control machine (MikeInspiron or MikePC):

```bash
# Debian/Ubuntu
sudo apt install ansible

# Arch
sudo pacman -S ansible
```

## Usage

```bash
cd homelab-infra/ansible

# Test connectivity
ansible archbox -i inventory.ini -m ping

# Full bootstrap (dry run first)
ansible-playbook -i inventory.ini archbox.yml --check

# Apply
ansible-playbook -i inventory.ini archbox.yml

# Single role only
ansible-playbook -i inventory.ini archbox.yml --tags nftables
```

## Roles

| Role | What it does |
|---|---|
| `base` | Package cache, core tools, SSH, IP forwarding, linger |
| `nftables` | Firewall with default-drop policy |
| `tailscale` | VPN mesh  -  prompts for manual auth if not authenticated |
| `podman` | Rootless Podman, subuid/subgid, quadlet deployment |
| `adguard` | DNS-level ad blocking, disables systemd-resolved |
| `crowdsec` | Intrusion detection + nftables bouncer |
| `agency` | Clones RingCatch agency repo, starts pod if .env present |

## Notes

- Tailscale auth requires manual `sudo tailscale up --advertise-exit-node` after first run
- `.env` for agency pod must be copied manually  -  never in git
- AdGuardHome.yaml has passwords redacted  -  restore from backup before running adguard role
- Run from inside the LAN or over Tailscale
