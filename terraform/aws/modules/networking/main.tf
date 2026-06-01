resource "aws_security_group" "ringcatch" {
  name        = "ringcatch-sg"
  description = "RingCatch EC2 - SSH from home, Tailscale, outbound all"

  # SSH — home IP only
  ingress {
    description = "SSH from home"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.home_ip}/32"]
  }

  # Tailscale — UDP 41641
  ingress {
    description = "Tailscale"
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound — required for Cloudflare Tunnel (outbound-only)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NOTE: No HTTP/HTTPS inbound — Cloudflare Tunnel uses outbound connections only.
  # If Tunnel isn't working yet and you need to debug, temporarily add:
  # ingress { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["your-ip/32"] }
}
