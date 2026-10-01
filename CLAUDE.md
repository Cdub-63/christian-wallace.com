# CLAUDE.md

Personal portfolio site — deployed via GitOps on k3s (Hetzner).

## Access

- **SSH:** `ssh k3s` (root@178.105.67.27, Falkenstein)
- **ArgoCD:** https://argocd.christian-wallace.com
- **Grafana:** https://grafana.christian-wallace.com
- **Site:** https://christian-wallace.com

## Hard Rule: Infrastructure as Code Only

All changes, infra or not, go on a branch with a PR to main. Never push to main directly and never merge a PR yourself; Christian reviews and merges.

Every infra change goes through code in this repo — never the Hetzner/Cloudflare consoles, `hcloud` CLI writes, or `kubectl apply/edit/patch` against the cluster.
- Hetzner + Cloudflare: change `terraform/` on a branch and open a PR to main. HCP Terraform (org `christian-wallace`, workspace `christian-wallace-com`, VCS-driven) posts a speculative plan as a PR check; review it, then merge, which auto-applies (CLI apply is rejected). Never push `terraform/` changes straight to main. `terraform plan` locally runs a speculative remote plan. Tokens are sensitive workspace vars (sourced from 1Password); never write them to files or print them. If something already exists outside Terraform, `terraform import` it — don't recreate or hand-edit.
- Kubernetes: change `manifests/` or `k3s/*-values.yaml` on a branch and open a PR to main; ArgoCD syncs once it is merged (ArgoCD manages itself via `app-argocd.yaml`). `k3s/config.yaml` and `terraform/cloud-init.yaml` only apply when a server is created. Read-only `kubectl get/describe/logs` is fine.
- `terraform plan` must show no changes after any infra work; drift means something was done by hand and must be codified or reverted.
- If a manual step is truly unavoidable (e.g. break-glass), codify it in the same session and note why in the commit.

## Stack

- **Infra-as-code:** Terraform (hcloud + cloudflare providers) in `terraform/`
- **Kubernetes:** k3s single-node, manifests in `manifests/`
- **Ingress:** Traefik (k3s built-in), TLS via cert-manager + Let's Encrypt
- **GitOps:** ArgoCD (auto-sync + self-heal)
- **CI/CD:** GitHub Actions — builds Docker image, pushes to GHCR, updates image tag + change-cause annotation in `manifests/site/deployment.yaml`, commits back
- **Site:** nginx:alpine (non-root, port 8080), HTML in `site/`
- **Observability:** kube-prometheus-stack in `monitoring` namespace; Grafana at grafana.christian-wallace.com. Alertmanager routes alerts to Discord and pings healthchecks.io every minute from `Watchdog` (dead man's switch); both URLs live in the `alertmanager-discord` Secret, sourced from `op://K3s/alertmanager-discord/{webhook-url,healthchecks-url}`
