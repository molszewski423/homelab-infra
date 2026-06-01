locals {
  tunnel_cname = "${var.cloudflare_tunnel_id}.cfargotunnel.com"
  zone_id      = var.cloudflare_zone_id
}

# Tunnel ingress config
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "ringcatch" {
  account_id = var.cloudflare_account_id
  tunnel_id  = var.cloudflare_tunnel_id

  config {
    ingress_rule {
      hostname = "ringcatch.io"
      service  = "http://agency-landing:80"
    }
    ingress_rule {
      hostname = "dashboard.ringcatch.io"
      service  = "http://agency-command:8100"
    }
    ingress_rule {
      hostname = "cfo.ringcatch.io"
      service  = "http://agency-cfo:8108"
    }
    ingress_rule {
      hostname = "n8n.ringcatch.io"
      service  = "http://agency-n8n:5678"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# DNS records — all proxied through Cloudflare
resource "cloudflare_record" "root" {
  zone_id         = local.zone_id
  name            = "@"
  content         = local.tunnel_cname
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}

resource "cloudflare_record" "www" {
  zone_id         = local.zone_id
  name            = "www"
  content         = local.tunnel_cname
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}

resource "cloudflare_record" "dashboard" {
  zone_id         = local.zone_id
  name            = "dashboard"
  content         = local.tunnel_cname
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}

resource "cloudflare_record" "cfo" {
  zone_id         = local.zone_id
  name            = "cfo"
  content         = local.tunnel_cname
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}

resource "cloudflare_record" "n8n" {
  zone_id         = local.zone_id
  name            = "n8n"
  content         = local.tunnel_cname
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}
