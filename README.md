# christian-wallace.com

Personal portfolio and Kubernetes homelab. Resume, blog, and more — deployed via GitOps on a self-managed k3s cluster.

## Tech Stack

| Layer | Tool | Purpose |
|---|---|---|
| **DNS** | Cloudflare | Domain management, proxying |
| **Infrastructure** | Terraform + Hetzner | Server provisioning as code |
| **Kubernetes** | k3s | Lightweight single-node cluster |
| **Ingress** | Traefik | HTTP/HTTPS routing (k3s built-in) |
| **TLS** | cert-manager + Let's Encrypt | Automatic certificate management |
| **GitOps** | ArgoCD | Declarative, Git-driven deployments |
| **CI/CD** | GitHub Actions | Build and push on merge to main |
| **Observability** | Prometheus + Grafana | Metrics and dashboards (Month 2) |

## Infrastructure Diagram

```mermaid
graph TB
    User([User / Browser])
    CF[Cloudflare DNS<br/>christian-wallace.com]
    GH[GitHub<br/>Cdub-63/christian-wallace.com]

    subgraph Hetzner ["Hetzner CPX21 — Ashburn, VA (87.99.148.36)"]
        subgraph k3s ["k3s Cluster"]
            Traefik[Traefik Ingress<br/>:80 / :443]

            subgraph argocd-ns ["namespace: argocd"]
                ArgoCD[ArgoCD<br/>GitOps Controller]
            end

            subgraph cert-ns ["namespace: cert-manager"]
                CertManager[cert-manager<br/>Let's Encrypt TLS]
            end

            subgraph site-ns ["namespace: default"]
                Site[Site Pod<br/>nginx + HTML]
            end
        end
    end

    LE[Let's Encrypt<br/>ACME]

    User -->|HTTPS| CF
    CF -->|A record → 87.99.148.36| Traefik
    Traefik --> Site
    GH -->|webhook| ArgoCD
    ArgoCD -->|reconcile manifests| Site
    CertManager <-->|ACME challenge| LE
    CertManager -->|TLS cert| Traefik
```

## Repository Layout

```
christian-wallace.com/
├── terraform/          # Hetzner server + firewall provisioning
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── manifests/          # Kubernetes manifests (ArgoCD-managed)
│   ├── argocd/
│   ├── cert-manager/
│   └── site/
├── site/               # HTML/CSS source for the website
└── .github/workflows/  # CI/CD (coming Month 2)
```

## Local Setup

**Prerequisites:** `kubectl`, `helm`, `terraform`, `k9s`, `hcloud`

```bash
# Clone
git clone git@github.com:Cdub-63/christian-wallace.com.git
cd christian-wallace.com

# Add secrets (gitignored)
echo 'hcloud_token = "..."' > terraform/terraform.tfvars.local

# Provision infrastructure
cd terraform
terraform init
terraform apply -var-file="terraform.tfvars.local"

# View cluster
kubectl get pods -A
k9s
```

## Roadmap

- [x] **Month 1 — Ship it**
  - [x] Hetzner server provisioned via Terraform
  - [x] k3s cluster running
  - [ ] Cloudflare DNS → server
  - [ ] cert-manager (automatic TLS)
  - [ ] ArgoCD (GitOps)
  - [ ] Site live at christian-wallace.com

- [ ] **Month 2 — Go deeper**
  - [ ] RBAC, NetworkPolicy, resource limits, HPA
  - [ ] Prometheus + Grafana observability
  - [ ] GitHub Actions CI/CD pipeline
  - [ ] Blog posts documenting architecture decisions

- [ ] **Month 3 — Harden & prep**
  - [ ] Second Hetzner node (HA, etcd concepts)
  - [ ] Security hardening (PodSecurityAdmission, Falco, sealed secrets)
  - [ ] Architecture write-up
