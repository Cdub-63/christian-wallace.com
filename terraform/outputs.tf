output "server_ip" {
  description = "Public IPv4 of the k3s node"
  value       = hcloud_server.k3s.ipv4_address
}
