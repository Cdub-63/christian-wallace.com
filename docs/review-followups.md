# Site Review Follow-ups

Work items from the October 2026 external review of the site and cluster.

## Done

- [x] Host joined to the tailnet; SSH and kubectl via `k3s.tailba717.ts.net` (PR #16)
- [x] Ports 22 and 6443 closed publicly; 80/443 allowed only from Cloudflare ranges; origin IP removed from README (PR #17)
- [x] Link previews (meta description, Open Graph/Twitter tags, favicons) on every page; headshot moved out of the HTML to `site/images/headshot.webp` (PR #19)
- [x] nginx hardening: security headers (CSP, HSTS, nosniff, Referrer-Policy, Permissions-Policy, frame-ancestors), cache headers, custom 404
- [x] README no longer mentions a blog
- [x] HPA/PDB single-node limits documented in `docs/why-each-tool.md`

## Remaining

- [ ] **CI gates** (`.github/workflows/build-push.yml`): pin actions to commit SHAs, add a Trivy image scan, and add an HTML and link check
- [ ] **Interview prep:** have an answer for how the 99.999% Transit Gateway uptime figure on `engineering.html` was measured

## Skipped

- Phone number on `human.html` and `resume.html`: it's a Google Voice number, so exposure is acceptable
