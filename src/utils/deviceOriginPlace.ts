import type { Place } from '../stores/routeStore'
import { pickBestReverseGeocodeResult } from './reverseGeocode'
import {
  geocoderStatusMessage,
  reverseGeocodeLatLng,
} from './reverseGeocodeRequest'

export function getCurrentPositionBestEffort(): Promise<GeolocationPosition> {
  const run = (options: PositionOptions) =>
    new Promise<GeolocationPosition>((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, options)
    })

  return run({
    enableHighAccuracy: true,
    timeout: 14_000,
    maximumAge: 0,
  }).catch((err: GeolocationPositionError) => {
    if (err?.code === 3) {
      return run({
        enableHighAccuracy: false,
        timeout: 12_000,
        maximumAge: 0,
      })
    }
    throw err
  })
}

export type DeviceOriginResult = {
  place: Place
  /** Non-fatal reverse-geocode issues (autodetect can ignore). */
  geoHint: string | null
}

/**
 * Reads device GPS and reverse-geocodes to a {@link Place} (same rules as the Origin locate button).
 */
export async function resolvePlaceFromDeviceGeolocation(): Promise<DeviceOriginResult> {
  const pos = await getCurrentPositionBestEffort()
  const lat = pos.coords.latitude
  const lng = pos.coords.longitude
  const { results, status } = await reverseGeocodeLatLng(lat, lng)

  if (results.length > 0) {
    const r = pickBestReverseGeocodeResult(results, lat, lng)
    if (r) {
      const name =
        r.formatted_address ?? `${lat.toFixed(6)}, ${lng.toFixed(6)}`
      return {
        place: {
          name,
          lat,
          lng,
          placeId: r.place_id,
        },
        geoHint: null,
      }
    }
  }

  const name = `${lat.toFixed(6)}, ${lng.toFixed(6)}`
  return {
    place: { name, lat, lng },
    geoHint:
      results.length === 0
        ? geocoderStatusMessage('ZERO_RESULTS')
        : geocoderStatusMessage(status),
  }
}
