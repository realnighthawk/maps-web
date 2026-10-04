/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_GOOGLE_MAPS_API_KEY: string
  /** Cloud Console Map ID for Advanced Markers; optional (defaults to DEMO_MAP_ID). */
  readonly VITE_GOOGLE_MAPS_MAP_ID?: string
  /**
   * Production maps-engine public origin (no path), e.g. https://maps-api.example.com.
   * Unset in local dev: API uses same-origin `/api/v1` and Vite proxies to MAPS_ENGINE_PROXY_TARGET.
   */
  readonly VITE_MAPS_ENGINE_ORIGIN?: string
  /**
   * The shared router's public origin (no path). With it the app signs in with Clerk and calls the user's own
   * maps-engine through `/maps/api/v1`. Needs VITE_CLERK_PUBLISHABLE_KEY, and this site's origin in the router's
   * ROUTER_ALLOWED_ORIGINS.
   */
  readonly VITE_ROUTER_ORIGIN?: string
  /** Clerk publishable key (public by design). Required when VITE_ROUTER_ORIGIN is set. */
  readonly VITE_CLERK_PUBLISHABLE_KEY?: string
  /**
   * Vite `base` for GitHub project Pages (`/repo-name/`). Defaults to `/` in vite.config.
   */
  readonly VITE_BASE_PATH?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
