# Site Review Follow-ups

Work items from the October 2026 external review of the site and cluster.

## Done

- [x] Host joined to the tailnet; SSH and kubectl via `k3s.tailba717.ts.net` (PR #16)
- [x] Ports 22 and 6443 closed publicly; 80/443 allowed only from Cloudflare ranges; origin IP removed from README (PR #17)
- [x] Link previews (meta description, Open Graph/Twitter tags, favicons) on every page; headshot moved out of the HTML to `site/images/headshot.webp`

## Remaining

- [ ] **nginx hardening** (`default.conf`): security headers (CSP, X-Content-Type-Options, Referrer-Policy, Permissions-Policy, frame-ancestors), cache headers for static assets, and a custom 404 page. Cloudflare already handles compression, so skip gzip. Check with securityheaders.com afterward.
- [ ] **CI gates** (`.github/workflows/build-push.yml`): pin actions to commit SHAs, add a Trivy image scan, and add an HTML and link check
- [ ] **README:** remove the mention of a blog, or build one
- [ ] **Docs:** note that the HPA (`minReplicas: 2`) and PDB only cover pod failure, not node loss, on a single node
- [ ] **Interview prep:** have an answer for how the 99.999% Transit Gateway uptime figure on `engineering.html` was measured

## Skipped

- Phone number on `human.html` and `resume.html`: it's a Google Voice number, so exposure is acceptable
