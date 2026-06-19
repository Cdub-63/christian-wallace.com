# CLAUDE.md

Personal portfolio site — deployed via GitOps on k3s (Hetzner).

## Stack

- **Infra-as-code:** Terraform (hcloud + cloudflare providers) in `terraform/`
- **Kubernetes:** k3s single-node, manifests in `manifests/`
- **Ingress:** Traefik (k3s built-in), TLS via cert-manager + Let's Encrypt
- **GitOps:** ArgoCD (auto-sync + self-heal)
- **CI/CD:** GitHub Actions — builds Docker image, pushes to GHCR, updates image tag + change-cause annotation in `manifests/site/deployment.yaml`, commits back
- **Site:** nginx:alpine (non-root, port 8080), HTML in `site/`
- **Observability:** kube-prometheus-stack in `monitoring` namespace; Grafana at grafana.christian-wallace.com
