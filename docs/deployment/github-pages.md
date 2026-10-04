# GitHub Pages (maps-web)

This app is a static Vite + React SPA. GitHub Pages serves the built assets from `dist/`; **`maps-engine` runs separately** (for example behind `https://maps-api.nighthawklabs.org`).

## One-time setup

1. **Repository → Settings → Pages**
   - **Build and deployment → Source:** GitHub Actions.

2. **Repository → Settings → Secrets and variables → Actions**
   - **Secrets:** add `VITE_GOOGLE_MAPS_API_KEY` (Google Maps JavaScript API key; embedded in the client bundle at build time).
   - **Variables:**
     - `VITE_MAPS_ENGINE_ORIGIN` — public origin of the API, **no path** (example: `https://maps-api.nighthawklabs.org`).
     - `VITE_BASE_PATH` — optional. Only set this if you need to override the default. On **GitHub Actions**, `vite.config` infers `/<repo>/` from `GITHUB_REPOSITORY` so assets load under `https://<owner>.github.io/<repo>/assets/`. Set `VITE_BASE_PATH=/` for a **custom domain** (or user/org site) served at the **domain root**. Do **not** set `VITE_BASE_PATH=/` for a normal **project** site (`…github.io/<repo>/`) or JS/CSS will 404 under `/assets/`.

   - **Router mode (to see your own drives and analytics):** also set the **variables** `VITE_ROUTER_ORIGIN` (the shared
     router, e.g. `https://harness-router.nighthawklabs.org`, no path) and `VITE_CLERK_PUBLISHABLE_KEY` (the same
     publishable key the phone apps use; it is public by design). Both are needed. The app then asks you to sign in with
     Clerk and calls your own maps-engine through `<router>/maps/api/v1` with your session token. `VITE_MAPS_ENGINE_ORIGIN`
     is ignored in this mode.

3. **Backend CORS** — the browser calls the API on a **different origin** than GitHub Pages. `maps-engine` must allow your Pages origin in CORS (and WebSocket origin policy if applicable), or requests will fail.

## Local production-like build

```bash
export VITE_MAPS_ENGINE_ORIGIN=https://maps-api.nighthawklabs.org
export VITE_BASE_PATH=/
npm run build
```

Adjust `VITE_BASE_PATH` to match how you host the static files.

## Router mode: what else has to be in place

- **The router must allow this site's origin.** Set `ROUTER_ALLOWED_ORIGINS` on the router (comma-separated exact origins,
  for example `https://<owner>.github.io`) and redeploy it. Without that the browser blocks the calls.
- **Clerk:** add this site's origin to the Clerk instance's allowed origins if Clerk asks (development instances usually don't).
- **maps-engine must be new enough** for the Drives tab: it uses `GET /journeys` (with summaries), `/journeys/stats`,
  `/journeys/{id}/sensors`, `/route` and `/series`. Roll the tenant image after the engine change.
- **Live fleet stream:** a browser WebSocket can't send an `Authorization` header, so the live fleet updates are off in
  router mode. Everything else (planning, fleet list, trips, drives) works.
- **Local development against a real instance** without signing in: port-forward the tenant's maps-engine and proxy
  `/api` to it: set `MAPS_ENGINE_PROXY_TARGET` to the forwarded address and `MAPS_ENGINE_VERIFIED_USER` to the Clerk user id
  the engine expects, and the dev proxy sends the `X-Nighthawk-Verified-User` header for you (see `.env.example`).
