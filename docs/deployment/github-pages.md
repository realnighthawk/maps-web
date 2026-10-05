# GitHub Pages (maps-web)

This app is a static Vite + React SPA. GitHub Pages serves the built assets from `dist/`; **`maps-engine` runs separately** (for example behind `https://maps-api.nighthawklabs.org`).

## One-time setup

1. **Repository → Settings → Pages**
   - **Build and deployment → Source:** GitHub Actions.

2. **Repository → Settings → Secrets and variables → Actions**
   - **Secrets:** add `VITE_GOOGLE_MAPS_API_KEY` (Google Maps JavaScript API key; embedded in the client bundle at build time).
   - **Variables:**
     - `VITE_CLERK_PUBLISHABLE_KEY` — the same publishable key the phone apps use (public by design). Required: the site is always behind Clerk.
     - `VITE_ROUTER_ORIGIN` — optional; defaults to `https://harness-router.nighthawklabs.org`. The site calls your own maps-engine through `<router>/maps/api/v1` with your session token.
     - `VITE_BASE_PATH` — optional. Only set this if you need to override the default. On **GitHub Actions**, `vite.config` infers `/<repo>/` from `GITHUB_REPOSITORY` so assets load under `https://<owner>.github.io/<repo>/assets/`. Set `VITE_BASE_PATH=/` for a **custom domain** (or user/org site) served at the **domain root**. Do **not** set `VITE_BASE_PATH=/` for a normal **project** site (`…github.io/<repo>/`) or JS/CSS will 404 under `/assets/`.

3. **Router CORS** — the browser calls the router on a **different origin** than the site, so the router must allow it (see below).

## Local production-like build

```bash
export VITE_ROUTER_ORIGIN=https://harness-router.nighthawklabs.org
export VITE_CLERK_PUBLISHABLE_KEY=pk_...
export VITE_BASE_PATH=/
npm run build
```

Adjust `VITE_BASE_PATH` to match how you host the static files.

## Router mode: what else has to be in place

- **The router must allow this site's origin.** Set `ROUTER_ALLOWED_ORIGINS` on the router (comma-separated; exact origins or a
  wildcard like `https://*.nighthawklabs.org`, already in the chart) and redeploy it. Without that the browser blocks the calls.
- **Clerk:** add this site's origin to the Clerk instance's allowed origins if Clerk asks (development instances usually don't).
- **maps-engine must be new enough** for the Trips tab: it uses `GET /journeys` (with summaries), `/journeys/stats`,
  `/journeys/{id}/sensors`, `/route` and `/series`. Roll the tenant image after the engine change.
- **Live fleet stream:** a browser WebSocket can't send an `Authorization` header, so the live fleet updates are off in
  router mode. Everything else (planning, fleet list, trips, drives) works.
- **Local development against a real instance** without signing in: port-forward the tenant's maps-engine and proxy
  `/api` to it: set `MAPS_ENGINE_PROXY_TARGET` to the forwarded address and `MAPS_ENGINE_VERIFIED_USER` to the Clerk user id
  the engine expects, and the dev proxy sends the `X-Nighthawk-Verified-User` header for you (see `.env.example`).
