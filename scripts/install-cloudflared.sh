#!/usr/bin/env bash
set -e
echo "==> Downloading cloudflared..."
curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

echo "==> Creating service..."
cat > /etc/systemd/system/ringcatch-cloudflared.service << 'UNIT'
[Unit]
Description=Cloudflare tunnel RingCatch failover
After=network-online.target nginx.service
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token eyJhIjoiYzdmNzczNzhjZjUzYjU0MzZkYWNiYzZhOGU2NzNjYzQiLCJ0IjoiMmVmMDk0MjUtZWQ4Ny00YzA3LWEwZTQtZWNjYTIwNDFkY2RmIiwicyI6ImhJNEtkVWthWXJaOVhNbURQdXFUQnU2aFpNaG82OXVHc1F1cXR6WVVNZ0E9In0=
# Alias read by cloudflared (it expects TUNNEL_TOKEN, not CLOUDFLARE_TUNNEL_TOKEN)
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now ringcatch-cloudflared
echo "==> Done"
systemctl status ringcatch-cloudflared --no-pager | head -8
