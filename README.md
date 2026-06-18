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
| **CI/CD** | GitHub Actions | Build and push image on changes to site or Dockerfile |
| **Container image** | Docker + nginx:alpine | HTML files baked into image at build time |
| **Container registry** | GHCR | Stores versioned Docker images alongside the repo |
| **Observability** | Prometheus + Grafana | Metrics and dashboards (Month 2) |

## Infrastructure Diagram

```mermaid
graph TB
    User([User / Browser])
    CF[Cloudflare DNS<br/>christian-wallace.com]
    GH[GitHub<br/>Cdub-63/christian-wallace.com]
    Actions[GitHub Actions<br/>Build + Push]
    GHCR[GHCR<br/>ghcr.io/cdub-63/christian-wallace-site]

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
                Site[Site Pod<br/>nginx:alpine + HTML]
            end
        end
    end

    LE[Let's Encrypt<br/>ACME]

    User -->|HTTPS| CF
    CF -->|A record → 87.99.148.36| Traefik
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

**Without Terraform:**
You SSH into Hetzner's dashboard, click through a web UI to create a server, manually set firewall rules, and hope you remember what you did if you ever need to rebuild. With Terraform, the server, firewall, and SSH key are code — `terraform apply` rebuilds the exact same thing from scratch in 30 seconds.

**Without Cloudflare DNS-as-code:**
You log into the Cloudflare dashboard and manually type in the IP address. If you ever reprovision the server and get a new IP, you have to remember to go update it. With Terraform managing the DNS record, `terraform apply` updates the A record automatically whenever the server IP changes.

**Without cert-manager:**
You go to Let's Encrypt, prove you own the domain by manually placing a file on your server, download the certificate files, upload them to Kubernetes as a Secret, configure Traefik to use them, and set a calendar reminder to repeat all of this in 90 days when they expire. With cert-manager, you annotate an Ingress with `cert-manager.io/cluster-issuer: letsencrypt-prod` and it handles the proof, the issuance, the Secret, and the renewal — forever.

**Without Traefik (ingress):**
Every service you run needs its own public port (`:3000`, `:8080`, etc.) and you manage routing yourself. With Traefik, all traffic comes in on `:443` and it routes to the right service based on the hostname — `christian-wallace.com` goes to the site, `argocd.christian-wallace.com` goes to ArgoCD, all on the same IP.

**Without Helm:**
Installing cert-manager without Helm means finding the right GitHub release, downloading a single massive YAML file (~1,000 lines), applying it with `kubectl apply -f`, and hoping the defaults work for you. Want to change a setting (more replicas, different log level, resource limits)? You edit a file you don't own, which gets overwritten next time you upgrade. Upgrading means downloading a new YAML file and re-applying it — there's no record of what changed or what version you're on. With Helm, `helm install` tracks the version and your overrides, `helm upgrade` diffs cleanly, and `helm rollback` undoes it in one command.

**Without ArgoCD:**
Deploying a change means SSHing into the server, or running `kubectl apply` from your laptop with the right kubeconfig. If you change something manually and it breaks, there's no easy rollback and no record of what changed. With ArgoCD, the cluster watches your GitHub repo — push a commit, the cluster reconciles itself to match. Rollback is `git revert`.

**Without Docker + GitHub Actions:**
Updating the site meant cramming all the HTML into a Kubernetes ConfigMap (a 600-line YAML file), committing that generated file, and pushing. With a Dockerfile, the HTML is baked into a self-contained image at build time. GitHub Actions builds and pushes that image to GHCR automatically on every push — no manual steps, no generated files in version control.

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

### ArgoCD autosync doesn't redeploy on new images

ArgoCD syncs what's in Git — if the manifest hasn't changed, it does nothing. After wiring up the CI pipeline to build and push a new Docker image on every push, the site pods weren't updating. ArgoCD reported "Synced" because the deployment manifest in Git still had the old image tag.

**Fix:** Added a `sed` step at the end of the GitHub Actions workflow to rewrite the image tag in `manifests/site/deployment.yaml` and commit it back. ArgoCD detects the Git change, syncs, and rolls out the new pod. The CI commit is what drives the deploy, not the image push.

### kube-prometheus-stack OOM'd the node

Installing `kube-prometheus-stack` (Prometheus + Grafana + Alertmanager + exporters) on a Hetzner CPX21 (3 vCPU, 4 GB RAM) killed the node. k3s itself was already consuming ~1.8 GB, leaving barely 2 GB for everything else. On startup, Prometheus alone spiked past what was available, the node hit 52 MB free, the embedded SQLite database started timing out on every query, and the API server became unreachable.

**Fix:** Upgraded the node to CPX31 (4 vCPU, 8 GB RAM) via a one-line change to `server_type` in Terraform. Hetzner resizes in-place — same IP, data preserved, ~90 seconds of downtime.

