# How Each Tool Earns Its Place

Every tool here replaces something painful. This is what the stack looks like without it:

**Without Terraform:** Hetzner server, firewall, and SSH key would be manual console clicks with no record of what was done. A push to `terraform/` rebuilds all of it from scratch in about 30 seconds.

**Without Cloudflare DNS-as-code:** Reprovisioning the server would mean remembering to manually update the A record with the new IP. Terraform updates it automatically on every apply.

**Without cert-manager:** TLS would mean manually proving domain ownership, downloading certs, uploading them as Kubernetes Secrets, and remembering to repeat it every 90 days. One annotation (`cert-manager.io/cluster-issuer: letsencrypt-prod`) automates issuance and renewal forever.

**Without Traefik:** Every service would need its own public port. Traefik routes all traffic on `:443` by hostname, so `christian-wallace.com` and `argocd.christian-wallace.com` share one IP.

**Without Helm:** Installing cert-manager would mean downloading a ~1,000-line YAML file, applying it blind, and losing any record of what version or overrides are in place. Helm tracks both, and `helm rollback` undoes a bad upgrade in one command.

**Without HCP Terraform:** State would live in a gitignored file on one laptop, with no locking and no way to apply from another machine. HCP holds the state and runs plan/apply on every push, so Git is the only way infrastructure changes.

**Without ArgoCD:** Deploying would mean SSHing in or running `kubectl apply` from a laptop, with no rollback and no record of what changed. ArgoCD reconciles the cluster to Git on every push; rollback is `git revert`.

**Without Alertmanager routing:** Alerts fire but go nowhere. Grafana was OOMKilled about 30 times in one week and nobody knew until it was spotted by hand. Now every warning and critical alert lands in Discord.

**Without a dead man's switch:** If Prometheus, Alertmanager, or the node dies, alerts stop, and silence looks exactly like "everything is fine." The `Watchdog` alert always fires on purpose and is routed to healthchecks.io once a minute. When the pings stop, healthchecks.io, which runs outside the cluster, raises the alarm. Coverage is layered: UptimeRobot catches the site being down from outside, Alertmanager catches problems inside the cluster, and healthchecks.io catches the monitoring itself being broken.

**Without Docker + GitHub Actions:** Site updates would mean cramming HTML into a 600-line ConfigMap and committing the generated file. A Dockerfile bakes HTML into an image; Actions builds and pushes it to GHCR on every push.
