# Challenges & Lessons Learned

Real issues hit during the build, documented here because they're the kind of thing tutorials skip.

## New code didn't reach the site automatically

**Problem:** GitHub Actions built and pushed a new site image on every commit, but the live site kept showing the old version. ArgoCD, the GitOps tool managing deployments, only checks Git for what to run, not the container registry, so it never noticed a new image existed.

**Solution:** Added a step to the GitHub Actions pipeline that updates the image version in Git right after each build, so ArgoCD always sees the change and rolls it out on its own.

## Locking down the web server broke it

**Problem:** Running the nginx web server as a non-root user is a standard security hardening step, but doing it broke the server outright. nginx's default config binds to port 80, which needs root, and also breaks its file access when the filesystem is made read-only.

**Solution:** Reconfigured nginx to listen on port 8080 instead of 80, and added writable temp storage for its cache and PID files, so it runs securely without needing elevated permissions.

## The dashboard login password kept changing on its own

**Problem:** Grafana's admin password silently reset itself after routine Helm chart updates, locking people out with no warning.

**Solution:** Moved the password into a separate Kubernetes Secret that Helm updates don't touch, and added a 1Gi persistent volume so Grafana's database survives pod restarts instead of resetting, so login stays consistent going forward.

## Network security rules were being silently ignored

**Problem:** Kubernetes NetworkPolicy rules meant to restrict which services could talk to each other appeared to apply but did nothing. Flannel, the default networking layer in k3s, accepted them without error, then simply didn't enforce them.

**Solution:** Replaced Flannel with Cilium, a networking layer that actually enforces the rules, closing the gap.

## Config changes in Git weren't taking effect

**Problem:** Settings changes were committed to Git as usual, but the live system kept running the old configuration, causing three days of Grafana login failures before the mismatch was found.

**Solution:** Set ArgoCD to manage its own configuration the same way it manages everything else ("app of apps"), so any change committed to Git now applies automatically.

## Switching the network layer broke already-running services

**Problem:** After migrating from Flannel to Cilium, services that were already running kept using stale, broken network connections and started crashing, including Prometheus, the monitoring tool, which couldn't reach the Kubernetes API.

**Solution:** Restarted every running service right after the switch so each one picked up a fresh, working connection.

## A few services were missed in that restart

**Problem:** Ten days after the Cilium migration, 4 services were quietly still broken: the ArgoCD application controller, the metrics server, the storage provisioner, and the Traefik load balancer. They'd been running fine outwardly, so they were skipped during the initial restart.

**Solution:** Turned "restart everything" into a standard, no-exceptions step after any future networking change, rather than relying on spotting which services look broken.

## A monitoring install crashed the server

**Problem:** Installing Prometheus and Grafana (via the kube-prometheus-stack Helm chart) used more memory than the Hetzner server had available. The 4GB server was already down to 52MB free once k3s and the new pods started up, making it unresponsive.

**Solution:** Upgraded from a 4GB to an 8GB Hetzner server, a one-line Terraform change with about 90 seconds of downtime.

## Hosting costs doubled overnight for no clear reason

**Problem:** The monthly Hetzner bill jumped from ~$37 to $73 with no change in server size, caused by a pricing gap where Hetzner kept older, more expensive server plans on sale only in its US locations after rolling out cheaper ones in Europe.

**Solution:** Migrated the server to Hetzner's Falkenstein, Germany data center, cutting the bill to $8.99/month (an 88% reduction) with no drop in performance, plus a Cloudflare proxy tweak to offset the added distance for US visitors.

## Useful metrics were being generated but never collected

**Problem:** Traefik, the ingress router handling site traffic, was already producing detailed Prometheus metrics internally, but nothing was set up to collect them, so that data was effectively invisible.

**Solution:** Added a small Prometheus monitoring config (a PodMonitor) to start pulling Traefik's metrics into Grafana.

## Cilium was installed, but the old tool was still routing service traffic

**Problem:** Months after the Cilium migration, a check of `cilium-dbg status` showed `KubeProxyReplacement: False`. Cilium was handling pod networking and NetworkPolicy, but k3s's built-in kube-proxy was still translating every Service address through ~110 iptables rules. Nothing looked broken, so this went unnoticed. Removing kube-proxy also creates a chicken-and-egg problem: Cilium normally reaches the Kubernetes API through the `kubernetes` Service address, and that address only works if something is already routing Services.

**Solution:** Enabled `kubeProxyReplacement` in the Cilium Helm values and pointed Cilium directly at the API server (`k8sServiceHost: 127.0.0.1`, port 6443) so it no longer depends on Service routing. Let ArgoCD roll that out first, with kube-proxy still running as a safety net, and confirmed Services still worked. Then disabled kube-proxy in k3s (`disable-kube-proxy: true` in `/etc/rancher/k3s/config.yaml`), restarted k3s, and flushed the leftover `KUBE-*` iptables rules. Service traffic is now handled by Cilium's eBPF datapath. One side effect: the k3s restart briefly took the API server offline, and ArgoCD cached an "apiserver not ready" error on one app until a hard refresh cleared it.

## Certificates depended on things ArgoCD didn't know about

**Problem:** Every HTTPS certificate depends on cert-manager and its Let's Encrypt ClusterIssuers existing first, but both had been installed by hand (Helm and `kubectl apply`), outside ArgoCD. On a rebuilt cluster, ArgoCD would create the site and Grafana Ingresses with nothing in place to issue their certificates. Adding ArgoCD sync waves to fix the ordering had two catches. Waves only order resources inside a single Application, so they do nothing on resources ArgoCD doesn't manage. And in an app-of-apps setup, ArgoCD treats a child Application as healthy the moment it exists, so a later wave never actually waits for an earlier one to finish.

**Solution:** Brought cert-manager (wave `-2`) and the ClusterIssuers (wave `-1`) under the root app as their own Applications, with everything else at the default wave `0`. Pinned the cert-manager chart to the exact version already installed (`v1.21.1`), since a floating version had caused trouble before (and pinned kube-prometheus-stack, which was still on `"*"`, to its running `91.8.1`), and checked with a server-side `kubectl diff` that ArgoCD's render matched the running resources before handing it over. Then turned the Application health check back on in `argocd-cm` (`k3s/argocd-values.yaml`) so root now waits for each wave to become healthy before starting the next.

## Terraform state lived on one laptop and fell out of date

**Problem:** Terraform's state file, its record of what it manages, was gitignored and existed only on one Mac. The Falkenstein migration was done from a Windows machine that had no state, so the Mac's state still described the deleted Ashburn server. Running `terraform apply` there would have created a second server and pointed all DNS at it. There was also no locking, and no way to apply from anywhere else.

**Solution:** Removed the dead server from state and ran `terraform import` on the live one, with `ignore_changes = [ssh_keys]` because Hetzner's API doesn't return SSH keys and the import otherwise forces a replacement. Ran a refresh-only apply to record the manual DNS changes, then moved state to HCP Terraform and connected the workspace to this repo with auto-apply. API tokens are sensitive workspace variables sourced from 1Password, and CLI applies are rejected, so a push is now the only way infrastructure changes, the same as ArgoCD for the cluster.

## Replacing the server would have produced an empty machine

**Problem:** Terraform created a bare Ubuntu server, but k3s, Cilium, ArgoCD, and the Grafana login Secret had all been installed by hand, and ArgoCD's own Helm release was upgraded manually with a values file that had already drifted from the live release (`server.insecure` was set on the cluster but missing from Git). A push that replaced the server would have left the site down until someone rebuilt the cluster by hand. With auto-apply on, nothing stopped a bad commit from deleting the server either.

**Solution:** Added a cloud-init script to the Terraform server that clones this repo on first boot, installs k3s with `k3s/config.yaml`, installs Cilium first (no pod can start without a network layer, so ArgoCD can't install it), installs ArgoCD, creates the Grafana Secret with a random password, and applies the root app. Chart versions are read from the ArgoCD Application files so bootstrap and GitOps can't disagree. ArgoCD now manages its own Helm release through an Application, checked against the live cluster with a server-side diff first. The server has `prevent_destroy`, so rebuilding it takes a deliberate commit, and `user_data` is in `ignore_changes` so editing the bootstrap never forces a rebuild.

## Grafana kept getting killed for running out of memory

**Problem:** Grafana restarted with `OOMKilled` (exit 137) after about two days. Its memory limit was 256Mi, but `kubectl top` showed it using 246Mi only hours after starting, so normal use left almost no headroom. The two sidecar containers that load dashboards and datasources had no requests or limits, so the scheduler didn't count them and they could grow without bound.

**Solution:** Raised Grafana to 512Mi and gave the sidecars 128Mi, with requests equal to limits for memory. When request equals limit, the scheduler reserves exactly what the pod is allowed to use, so the node can't be overcommitted on memory and a spike can't take memory other pods were counting on. The pod had actually restarted around 30 times in a week, which only came out when Prometheus was queried, because Alertmanager was sending every alert to a `null` receiver. Alerts now go to Discord, including new rules for a container above 90% of its memory limit and for any OOMKill.

## Prometheus kept running close to its memory limit

**Problem:** The new memory alert fired for Prometheus at about 95% of its 512Mi limit, then resolved on its own. It had not been OOMKilled (restart count 0). Prometheus holds the last two hours of samples in memory and writes them to disk every two hours, so its memory use rises steadily and then drops after each write. At 512Mi the high points came within a few percent of the limit, so any growth in the number of tracked series would have caused OOMKills.

**Solution:** Raised the Prometheus memory request and limit to 1Gi, keeping request equal to limit as was done for Grafana. The alert resolving by itself didn't mean the problem had gone away. The value in the resolved message was the last reading before memory dropped, and that pattern repeats every two hours.

## The site had no health checks

**Problem:** An audit of the cluster's workloads found the site's pod had no liveness or readiness probes. Kubernetes only knew the nginx process existed, not whether it could serve pages. A hung nginx would have stayed `Running` and kept receiving traffic, and during a rollout the new pod could get traffic before it was ready.

**Solution:** Added an HTTP readiness probe on `/` so the pod only gets traffic once nginx is actually serving, and a shallow TCP liveness probe on port 8080 so Kubernetes restarts the container if nginx stops listening. Liveness is kept shallow on purpose, because a deeper check could restart a healthy pod over a slow response. The first rollout logged one `connection refused` readiness failure because the probe ran before nginx had bound its port, so readiness now waits 2 seconds before its first check.
