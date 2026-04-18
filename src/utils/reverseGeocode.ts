/**
 * Picks the best Geocoder result for reverse-geocoding a GPS point.
 * Google's first result is often a large region; street-level matches are usually better.
 */
export function pickBestReverseGeocodeResult(
  results: google.maps.GeocoderResult[],
  deviceLat: number,
  deviceLng: number,
): google.maps.GeocoderResult | undefined {
  if (!results.length) return undefined

  const distSq = (r: google.maps.GeocoderResult): number => {
    const loc = r.geometry?.location
    if (!loc) return Number.POSITIVE_INFINITY
    const dLat = loc.lat() - deviceLat
    const dLng = loc.lng() - deviceLng
    return dLat * dLat + dLng * dLng
  }

  const scored = results.map((r) => ({
    r,
    score: scoreReverseGeocodeResult(r),
    distance: distSq(r),
  }))

  const maxScore = Math.max(...scored.map((s) => s.score))
  const tier = scored.filter((s) => s.score >= maxScore - 8)
  tier.sort((a, b) => a.distance - b.distance)
  return tier[0]?.r ?? scored.sort((a, b) => b.score - a.score)[0]?.r
}

function scoreReverseGeocodeResult(r: google.maps.GeocoderResult): number {
  let score = 0
  const lt = r.geometry?.location_type as string | undefined
  switch (lt) {
    case 'ROOFTOP':
      score += 100
      break
    case 'RANGE_INTERPOLATED':
      score += 85
      break
    case 'GEOMETRIC_CENTER':
      score += 55
      break
    case 'APPROXIMATE':
      score += 25
      break
    default:
      score += 30
  }

  const types = new Set(r.types ?? [])
  if (types.has('street_address')) score += 45
  if (types.has('premise')) score += 40
  if (types.has('subpremise')) score += 35
  if (types.has('point_of_interest')) score += 28
  if (types.has('establishment')) score += 22
  if (types.has('intersection')) score += 20
  if (types.has('route')) score += 12
  if (types.has('sublocality') || types.has('sublocality_level_1')) score += 8
  if (types.has('neighborhood')) score += 6
  if (types.has('locality')) score += 4

  if (types.has('country') && types.size <= 2) score -= 120
  if (types.has('administrative_area_level_1') && types.size <= 2) score -= 80
  if (types.has('postal_code') && !types.has('street_address') && !types.has('route'))
    score -= 15

  return score
}
