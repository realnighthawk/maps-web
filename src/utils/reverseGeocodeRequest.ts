/**
 * Reverse-geocode with retries on transient Geocoder errors.
 * Requires the `geocoding` Maps library and Geocoding API enabled for the key.
 */
export async function reverseGeocodeLatLng(
  lat: number,
  lng: number,
): Promise<{
  results: google.maps.GeocoderResult[]
  status: google.maps.GeocoderStatus
}> {
  const geocoder = new google.maps.Geocoder()
  const request: google.maps.GeocoderRequest = { location: { lat, lng } }

  const once = (): Promise<{
    results: google.maps.GeocoderResult[]
    status: google.maps.GeocoderStatus
  }> =>
    new Promise((resolve) => {
      geocoder.geocode(request, (results, status) => {
        resolve({
          results: results ?? [],
          status: status as google.maps.GeocoderStatus,
        })
      })
    })

  const retryable = (status: string) =>
    status === 'UNKNOWN_ERROR' ||
    status === 'OVER_QUERY_LIMIT' ||
    status === 'ERROR'

  let last: {
    results: google.maps.GeocoderResult[]
    status: google.maps.GeocoderStatus
  } = { results: [], status: 'UNKNOWN_ERROR' as google.maps.GeocoderStatus }

  for (let attempt = 0; attempt < 3; attempt++) {
    if (attempt > 0) {
      await new Promise((r) => setTimeout(r, 400 * attempt))
    }
    try {
      last = await once()
    } catch {
      last = {
        results: [],
        status: 'UNKNOWN_ERROR' as google.maps.GeocoderStatus,
      }
      continue
    }

    if (last.status === 'OK') {
      return last
    }

    if (!retryable(last.status)) {
      return last
    }
  }

  return last
}

export function geocoderStatusMessage(
  status: google.maps.GeocoderStatus | 'ZERO_RESULTS',
): string {
  switch (status) {
    case 'ZERO_RESULTS':
      return 'No street address was found for this GPS point. Your coordinates are set—search above to pick a place.'
    case 'OVER_QUERY_LIMIT':
      return 'Address lookup quota exceeded. Coordinates are set; try again later or search for an address.'
    case 'REQUEST_DENIED':
      return 'Address lookup was denied. In Google Cloud, enable the Geocoding API for the same key as Maps JavaScript.'
    case 'INVALID_REQUEST':
      return 'Address lookup failed (invalid request). Coordinates are set—you can search for an address.'
    case 'UNKNOWN_ERROR':
      return 'Address lookup failed temporarily. Coordinates are set—try again or search for an address.'
    default:
      return 'Could not look up a street address. Coordinates are set—search above if you need a label.'
  }
}
