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

3. **Backend CORS** — the browser calls the API on a **different origin** than GitHub Pages. `maps-engine` must allow your Pages origin in CORS (and WebSocket origin policy if applicable), or requests will fail.

## Local production-like build

```bash
export VITE_MAPS_ENGINE_ORIGIN=https://maps-api.nighthawklabs.org
export VITE_BASE_PATH=/
npm run build
```

Adjust `VITE_BASE_PATH` to match how you host the static files.
