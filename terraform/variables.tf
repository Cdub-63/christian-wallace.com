variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  sensitive   = true
}

variable "cloudflare_token" {
  description = "Cloudflare API token (Zone:DNS:Edit)"
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for christian-wallace.com"
}
