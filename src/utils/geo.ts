export function latLngBounds(
  points: google.maps.LatLngLiteral[],
): google.maps.LatLngBoundsLiteral | null {
  if (points.length === 0) return null
  let north = -90, south = 90, east = -180, west = 180
  for (const p of points) {
    if (p.lat > north) north = p.lat
    if (p.lat < south) south = p.lat
    if (p.lng > east) east = p.lng
    if (p.lng < west) west = p.lng
  }
  return { north, south, east, west }
}
