terraform {
  cloud {
    organization = "christian-wallace"
    workspaces {
      name = "christian-wallace-com"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "A"
  content = hcloud_server.k3s.ipv4_address
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  type    = "A"
  content = hcloud_server.k3s.ipv4_address
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "argocd" {
  zone_id = var.cloudflare_zone_id
  name    = "argocd"
  type    = "A"
  content = hcloud_server.k3s.ipv4_address
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "grafana" {
  zone_id = var.cloudflare_zone_id
  name    = "grafana"
  type    = "A"
  content = hcloud_server.k3s.ipv4_address
  ttl     = 1
  proxied = false
}

resource "hcloud_ssh_key" "default" {
  name       = "christian-mac"
  public_key = file("${path.module}/ssh_key.pub")
}

resource "hcloud_firewall" "k3s" {
  name = "k3s-firewall"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "6443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "k3s" {
  name        = "k3s-node-1"
  image       = "ubuntu-24.04"
  server_type = "cx33"
  location    = "fsn1"
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.k3s.id]
  user_data   = file("${path.module}/cloud-init.yaml")

  labels = {
    role = "k3s-control-plane"
  }

  # Pushes auto-apply, so a bad commit must not be able to delete the server.
  # To rebuild on purpose: remove prevent_destroy in one commit, then replace.
  # user_data only runs at creation; ignoring it stops bootstrap edits from forcing a rebuild.
  # Hetzner's API doesn't return ssh_keys, so any import shows a forced replacement.
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ssh_keys, user_data]
  }
}
