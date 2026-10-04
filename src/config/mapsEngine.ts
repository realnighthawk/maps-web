/**
 * Production maps-engine origin (scheme + host, no path), e.g. https://maps-api.example.com.
 * When unset, the app uses same-origin `/api/v1` (local dev with Vite proxy).
 */
export function getMapsEngineOrigin(): string {
  return import.meta.env.VITE_MAPS_ENGINE_ORIGIN?.trim() ?? ''
}

/**
 * The shared router's public origin (scheme + host, no path). When set, the app talks to the signed-in user's own
 * maps-engine through it (`/maps/api/v1`) with a Clerk session token, instead of to an engine directly.
 */
export function getRouterOrigin(): string {
  return import.meta.env.VITE_ROUTER_ORIGIN?.trim() ?? ''
}

export function isRouterMode(): boolean {
  return getRouterOrigin() !== ''
}

export function getClerkPublishableKey(): string {
  return import.meta.env.VITE_CLERK_PUBLISHABLE_KEY?.trim() ?? ''
}

export function getApiV1Base(): string {
  const r = getRouterOrigin()
  if (r) return `${r.replace(/\/$/, '')}/maps/api/v1`
  const o = getMapsEngineOrigin()
  if (o) return `${o.replace(/\/$/, '')}/api/v1`
  return '/api/v1'
}

/** WebSocket URL for fleet live stream (maps-engine). */
export function getFleetLiveWebSocketUrl(): string {
  const path = '/api/v1/fleet/live'
  const o = getMapsEngineOrigin()
  if (o) {
    const u = new URL(o)
    const wsProto = u.protocol === 'https:' ? 'wss:' : 'ws:'
    return `${wsProto}//${u.host}${path}`
  }
  const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  return `${proto}//${window.location.host}${path}`
}
