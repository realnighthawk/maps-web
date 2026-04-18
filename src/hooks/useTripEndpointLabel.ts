import { useEffect, useState } from 'react'
import { pickBestReverseGeocodeResult } from '../utils/reverseGeocode'
import { reverseGeocodeLatLng } from '../utils/reverseGeocodeRequest'

const cache = new Map<string, string>()

function llKey(lat: number, lng: number): string {
  return `${lat.toFixed(6)},${lng.toFixed(6)}`
}

function coordFallback(lat: number, lng: number): string {
  return `${lat.toFixed(4)}, ${lng.toFixed(4)}`
}

/**
 * Reverse-geocodes a point for trip cards (cached). Shows "…" until resolved.
 */
export function useTripEndpointLabel(lat: number, lng: number): string {
  const [label, setLabel] = useState(() => cache.get(llKey(lat, lng)) ?? '…')

  useEffect(() => {
    const key = llKey(lat, lng)
    const hit = cache.get(key)
    if (hit) {
      setLabel(hit)
      return
    }

    setLabel('…')
    let cancelled = false

    ;(async () => {
      try {
        const { results, status } = await reverseGeocodeLatLng(lat, lng)
        if (cancelled) return
        let name = coordFallback(lat, lng)
        if (status === 'OK' && results.length) {
          const r = pickBestReverseGeocodeResult(results, lat, lng)
          if (r?.formatted_address) name = r.formatted_address
        }
        cache.set(key, name)
        if (!cancelled) setLabel(name)
      } catch {
        const fb = coordFallback(lat, lng)
        cache.set(key, fb)
        if (!cancelled) setLabel(fb)
      }
    })()

    return () => {
      cancelled = true
    }
  }, [lat, lng])

  return label
}
