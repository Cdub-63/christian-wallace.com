# CLAUDE.md

Personal portfolio site — deployed via GitOps on k3s (Hetzner).

## Access

- **SSH:** `ssh k3s` (root@178.105.67.27, Falkenstein)
- **ArgoCD:** https://argocd.christian-wallace.com
- **Grafana:** https://grafana.christian-wallace.com
- **Site:** https://christian-wallace.com

## Hard Rule: Infrastructure as Code Only

Every infra change goes through code in this repo — never the Hetzner/Cloudflare consoles, `hcloud` CLI writes, or `kubectl apply/edit/patch` against the cluster.
- Hetzner + Cloudflare: change `terraform/`, then `op run --env-file=.env.op -- terraform plan` → `apply`. Tokens come from 1Password only; never write them to files or print them. If something already exists outside Terraform, `terraform import` it — don't recreate or hand-edit.
- Kubernetes: change `manifests/` (or `k3s/` for node config), commit, let ArgoCD sync. Read-only `kubectl get/describe/logs` is fine.
- `terraform plan` must show no changes after any infra work; drift means something was done by hand and must be codified or reverted.
- If a manual step is truly unavoidable (e.g. break-glass), codify it in the same session and note why in the commit.

## Stack

- **Infra-as-code:** Terraform (hcloud + cloudflare providers) in `terraform/`
- **Kubernetes:** k3s single-node, manifests in `manifests/`
- **Ingress:** Traefik (k3s built-in), TLS via cert-manager + Let's Encrypt
- **GitOps:** ArgoCD (auto-sync + self-heal)
- **CI/CD:** GitHub Actions — builds Docker image, pushes to GHCR, updates image tag + change-cause annotation in `manifests/site/deployment.yaml`, commits back
- **Site:** nginx:alpine (non-root, port 8080), HTML in `site/`
- **Observability:** kube-prometheus-stack in `monitoring` namespace; Grafana at grafana.christian-wallace.com
