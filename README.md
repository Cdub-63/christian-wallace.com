# christian-wallace.com

Personal portfolio and Kubernetes homelab. Resume, blog, and more — deployed via GitOps on a self-managed k3s cluster.

## Tech Stack

| Layer | Tool | Purpose |
|---|---|---|
| **DNS** | Cloudflare | Domain management, proxying |
| **Infrastructure** | Terraform + Hetzner | Server provisioning as code |
| **Kubernetes** | k3s | Lightweight single-node cluster |
| **Ingress** | Traefik | HTTP/HTTPS routing (k3s built-in) |
| **Package manager** | Helm | Install and upgrade cluster apps (cert-manager, ArgoCD) |
| **TLS** | cert-manager + Let's Encrypt | Automatic certificate management |
| **GitOps** | ArgoCD | Declarative, Git-driven deployments |
| **GitOps (app-of-apps)** | ArgoCD root Application | Watches `manifests/argocd/` so Application manifest changes deploy automatically on push |
| **CI/CD** | GitHub Actions | Build and push image on changes to site or Dockerfile |
| **Container image** | Docker + nginx:alpine | HTML files baked into image at build time |
| **Container registry** | GHCR | Stores versioned Docker images alongside the repo |
| **CNI** | Cilium (eBPF) | Pod networking + NetworkPolicy enforcement; replaced Flannel which silently ignores NetworkPolicy |
| **Observability** | Prometheus + Grafana | Metrics and dashboards (Month 2) |
| **Grafana storage** | Kubernetes PVC (local-path, 1Gi) | Persists Grafana's SQLite DB across pod restarts |
| **Uptime monitoring** | UptimeRobot | External uptime checks with email alerts |

## Infrastructure Diagram

```mermaid
graph TB
    User([User / Browser])
    CF[Cloudflare DNS<br/>christian-wallace.com]
    GH[GitHub<br/>Cdub-63/christian-wallace.com]
    Actions[GitHub Actions<br/>Build + Push]
    GHCR[GHCR<br/>ghcr.io/cdub-63/christian-wallace-site]

    subgraph Hetzner ["Hetzner CX33 — Falkenstein, DE (178.105.67.27)"]
        subgraph k3s ["k3s Cluster"]
            Traefik[Traefik Ingress<br/>:80 / :443]

            subgraph argocd-ns ["namespace: argocd"]
                ArgoCD[ArgoCD<br/>GitOps Controller]
            end

            subgraph cert-ns ["namespace: cert-manager"]
                CertManager[cert-manager<br/>Let's Encrypt TLS]
            end

            subgraph site-ns ["namespace: default"]
                Site[Site Pod<br/>nginx:alpine + HTML]
            end
        end
    end

    LE[Let's Encrypt<br/>ACME]

    User -->|HTTPS| CF
    CF -->|A record → 178.105.67.27, proxied| Traefik
    Traefik --> Site
    GH -->|push triggers| Actions
    Actions -->|docker push| GHCR
    GH -->|polls for changes| ArgoCD
    ArgoCD -->|reconcile manifests| Site
    GHCR -->|pull image| Site
    CertManager <-->|ACME challenge| LE
    CertManager -->|TLS cert| Traefik
```

## How Each Tool Earns Its Place

Every tool here replaces something painful. This is what the stack looks like without it:

**Without Terraform:** Hetzner server, firewall, and SSH key would be manual console clicks with no record of what was done — `terraform apply` rebuilds all of it from scratch in 30 seconds.

**Without Cloudflare DNS-as-code:** Reprovisioning the server would mean remembering to manually update the A record with the new IP. Terraform updates it automatically on every apply.

**Without cert-manager:** TLS would mean manually proving domain ownership, downloading certs, uploading them as Kubernetes Secrets, and remembering to repeat it every 90 days. One annotation (`cert-manager.io/cluster-issuer: letsencrypt-prod`) automates issuance and renewal forever.

**Without Traefik:** Every service would need its own public port. Traefik routes all traffic on `:443` by hostname, so `christian-wallace.com` and `argocd.christian-wallace.com` share one IP.

**Without Helm:** Installing cert-manager would mean downloading a ~1,000-line YAML file, applying it blind, and losing any record of what version or overrides are in place. Helm tracks both, and `helm rollback` undoes a bad upgrade in one command.

**Without ArgoCD:** Deploying would mean SSHing in or running `kubectl apply` from a laptop, with no rollback and no record of what changed. ArgoCD reconciles the cluster to Git on every push; rollback is `git revert`.

**Without Docker + GitHub Actions:** Site updates would mean cramming HTML into a 600-line ConfigMap and committing the generated file. A Dockerfile bakes HTML into an image; Actions builds and pushes it to GHCR on every push.

## Repository Layout

```
christian-wallace.com/
├── Dockerfile          # nginx:alpine image with site/ baked in
├── terraform/          # Hetzner server + firewall provisioning
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── manifests/          # Kubernetes manifests (ArgoCD-managed)
│   ├── argocd/
│   ├── cert-manager/
│   └── site/
├── site/               # HTML/CSS source for the website
└── .github/workflows/  # GitHub Actions — build + push to GHCR
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

## Challenges & Lessons Learned

Real issues hit during the build, documented here because they're the kind of thing tutorials skip.

### New code didn't reach the site automatically

**Problem:** GitHub Actions built and pushed a new site image on every commit, but the live site kept showing the old version — the deployment tool only checks Git for what to run, not the container registry, so it never noticed a new image existed.

**Solution:** Added a step to the build pipeline that updates the version number in Git right after each build, so the deployment tool always sees the change and rolls it out on its own.

### Locking down the web server broke it

**Problem:** Running the web server as a non-root user is a standard security hardening step, but doing it broke the server outright — its default setup needs root-level access for its network port and file access.

**Solution:** Reconfigured the server to use an unprivileged port and writable temp storage, so it runs securely without needing elevated permissions.

### The dashboard login password kept changing on its own

**Problem:** The monitoring dashboard's admin password silently reset itself after routine updates, locking people out with no warning.

**Solution:** Moved the password into a separate, stable location that updates don't touch, so login stays consistent going forward.

### Network security rules were being silently ignored

**Problem:** Rules meant to restrict which services could talk to each other appeared to apply but did nothing — the underlying networking layer accepted them without error, then simply didn't enforce them.

**Solution:** Replaced that networking layer with one (Cilium) that actually enforces the rules, closing the gap.

### Config changes in Git weren't taking effect

**Problem:** Settings changes were committed to Git as usual, but the live system kept running the old configuration — causing three days of dashboard login failures before the mismatch was found.

**Solution:** Set the deployment tool to manage its own configuration the same way it manages everything else, so any change committed to Git now applies automatically.

### Switching the network layer broke already-running services

**Problem:** After upgrading the underlying networking system, services that were already running kept using stale, broken connections and started crashing.

**Solution:** Restarted every running service right after the switch so each one picked up a fresh, working connection.

### A few services were missed in that restart

**Problem:** Ten days after the networking upgrade, a handful of services were quietly still broken — they'd been running fine outwardly, so they were skipped during the initial restart.

**Solution:** Turned "restart everything" into a standard, no-exceptions step after any future networking change, rather than relying on spotting which services look broken.

### A monitoring install crashed the server

**Problem:** Installing the monitoring stack used more memory than the server had available, causing the whole server to become unresponsive.

**Solution:** Upgraded to a server with more RAM — a one-line config change with about 90 seconds of downtime.

### Hosting costs doubled overnight for no clear reason

**Problem:** The monthly bill jumped from ~$37 to $73 with no change in server size — caused by a pricing gap where the hosting provider kept older, more expensive server plans on sale only in its US locations after rolling out cheaper ones elsewhere.

**Solution:** Migrated the server to a European data center, cutting the bill to $8.99/month — an 88% reduction — with no drop in performance, plus a minor DNS tweak to offset the added distance for US visitors.

### Useful metrics were being generated but never collected

**Problem:** The site's traffic router was already producing detailed metrics internally, but nothing was set up to collect them, so that data was effectively invisible.

**Solution:** Added a small monitoring config to start pulling those metrics into the dashboard.

