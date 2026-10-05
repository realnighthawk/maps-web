# Deployment

maps-web ships as a Docker image (nginx serving the built SPA), published to `ghcr.io/realnighthawk/maps-web` by
`.github/workflows/publish-image.yml` on every push to `main` (`latest`, `sha-…`) and on `v*` tags. It is deployed by
the `mapsWeb` block of the shared chart in agent-harness (`mapsWeb.enabled`, `mapsWeb.ingress`).

## One-time repository setup (Settings → Secrets and variables → Actions)

- **Secret** `VITE_GOOGLE_MAPS_API_KEY` — Google Maps JavaScript API key (embedded in the bundle at build time).
- **Variable** `VITE_CLERK_PUBLISHABLE_KEY` — the publishable key the phone apps use (public by design). Required: the
  site is always behind Clerk.
- **Variable** `VITE_ROUTER_ORIGIN` — optional; defaults to `https://harness-router.nighthawklabs.org`.
- After the first publish, make the package public, or give the cluster an image pull secret for ghcr.io.

These are baked in when the image is built, so changing one means a new build.

## Local image

```bash
docker build -t maps-web --build-arg VITE_CLERK_PUBLISHABLE_KEY=pk_... --build-arg VITE_GOOGLE_MAPS_API_KEY=... .
docker run --rm -p 8080:8080 maps-web
```

## What else has to be in place

- **The router must allow the site's origin.** `ROUTER_ALLOWED_ORIGINS` accepts exact origins or a wildcard such as
  `https://*.nighthawklabs.org` (already in the shared chart). Serve the site on a host that matches.
- **Clerk:** add the site's origin to the instance's allowed origins if Clerk asks (development instances usually don't).
- **maps-engine must be new enough** for the Trips tab: it uses `GET /journeys` (with summaries), `/journeys/stats`,
  `/journeys/{id}/sensors`, `/route` and `/series`. Roll the tenant image after the engine change.
