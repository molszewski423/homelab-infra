# homelab-infra — Claude Code Context

k3s manifests and IaC for the 3-node home cluster.

**Control plane:** mikepc (192.168.4.54) — kubectl must be run here  
**Workers:** archbox (agency namespace) · mikeinspiron (traefik only, lid-closed)  
**Latest commit:** c729ac5 · remotes: origin=gitlab.com, gitea=git.lan

---

## Apply changes

```fish
kubectl apply -f ~/homelab-infra/k8s/agency.yaml
kubectl apply -f ~/homelab-infra/k8s/ollama.yaml   # and other ai namespace files
kubectl rollout status deployment/<name> -n <namespace> --timeout=90s
```

---

## k8s/ file map

| File | What it controls |
|---|---|
| agency.yaml | All 24 agency namespace Deployments + Services + PVCs |
| ollama.yaml | Ollama GPU pod (ai namespace, pinned to mikepc) |
| pv-workbench.yaml | PV Signal Intelligence Workbench (ai namespace) |
| ams-intelligence.yaml | Antimicrobial stewardship AI (ai namespace) |
| argus.yaml | Argus Discord bot (ai namespace) |
| ingress.yaml | Traefik ingress + LAN-only ipAllowList middleware |
| gitea.yaml | Self-hosted Gitea (infra namespace) |

---

## agency-tunnel (ringcatch.io)

Public site via Cloudflare tunnel. Key config in agency.yaml:
- Routes to k3s service DNS — **NOT localhost**. Cloudflare ingress config:
  - `ringcatch.io` / `www.ringcatch.io` → `http://agency-landing.agency.svc.cluster.local:80`
  - `dashboard.ringcatch.io` → `http://agency-dashboard.agency.svc.cluster.local:8501`
- No `hostNetwork`/`hostPID` — tunnel pod is in k3s overlay network so cluster DNS resolves
- Init container purges stale Cloudflare connections via API before pod starts
- `strategy: Recreate` — no rolling overlap during restarts
- `--metrics 0.0.0.0:2000` + liveness probe httpGet /ready :2000 (30s delay, 60s period, 3 failures)
- If 502/1033: `kubectl get pods -n agency -l app=agency-tunnel` then check logs
- **All agency services run exclusively in k3s** — Podman quadlets on archbox are disabled

---

## Pending (as of 2026-06-01)

1. **MikePC root disk at 91%:** `sudo journalctl --vacuum-size=200M && sudo apt-get clean`
2. **GitLab registry token expired** — ai namespace (pv-workbench, ams-intelligence, argus-bot) can't pull new images.
   Rotate at gitlab.com → repo Settings → Deploy tokens (scope: read_registry), then:
   `kubectl create secret docker-registry gitlab-registry --docker-server=registry.gitlab.com --docker-username=<name> --docker-password=<token> -n ai --dry-run=client -o yaml | kubectl apply -f -`
   After rotating, `kubectl apply -f ~/homelab-infra/k8s/` rolls out committed CPU reductions for ai namespace.

---

## Rules

- All secrets in `~/agency/.env` on archbox — never commit
- Custom agency images are `localhost/agency-*:latest` in k3s containerd on archbox — import manually
- nodeSelector `archbox` on all agency pods, `mikepc` on all ai pods
