# homelab-infra

Infrastructure as Code for a 25-service AI agency homelab running on a single low-power server (Intel i3-4130T).

## Stack

- **OS:** Debian 13 (archbox)
- **Containers:** Rootless Podman with systemd quadlets
- **Networking:** Cloudflare Tunnel (no open ports)
- **LLM routing:** Gemini 2.5 Flash → Ollama (MikePC RTX 5060 Ti) → Groq fallback

## Structure

| Directory | Description |
|---|---|
| `quadlets/` | Systemd quadlet container units (Podman) |
| `nginx/` | Nginx reverse proxy configs |
| `scripts/` | Tunnel management, backup, and deploy scripts |
| `landing/` | RingCatch landing page |

## Services (25 containers in agency-pod)

| Service | Port | Purpose |
|---|---|---|
| agency-orchestrator | 8109 | AI brain — FastAPI, 22 tools |
| agency-outreach | 8080 | Email sending + booking chat |
| agency-scraper | 8079 | Google Maps lead scraper |
| agency-command | 8100 | Dashboard / command center |
| agency-discord | 8103 | Discord bot bridge |
| agency-billing | 8082 | Billing service |
| agency-landing | 8090 | Public landing page |

## Deployment

```bash
# Deploy quadlets
cp quadlets/* ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start agency-pod

# Tunnel
bash scripts/tunnel-setup.sh
```
