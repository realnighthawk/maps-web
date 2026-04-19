/**
 * Production maps-engine origin (scheme + host, no path), e.g. https://maps-api.example.com.
 * When unset, the app uses same-origin `/api/v1` (local dev with Vite proxy).
 */
export function getMapsEngineOrigin(): string {
  return import.meta.env.VITE_MAPS_ENGINE_ORIGIN?.trim() ?? ''
}

export function getApiV1Base(): string {
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
