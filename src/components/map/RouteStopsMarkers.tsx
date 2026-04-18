import { AdvancedMarker, Pin } from '@vis.gl/react-google-maps'
import { useRouteStore } from '../../stores/routeStore'

/** A–Z labels for each row index (Google Maps–style). */
function rowLabel(index: number): string {
  return String.fromCharCode(65 + index)
}

function pinColors(index: number, total: number) {
  if (total <= 1) return { background: '#15803d', borderColor: '#ffffff' }
  if (index === 0) return { background: '#15803d', borderColor: '#ffffff' }
  if (index === total - 1) return { background: '#dc2626', borderColor: '#ffffff' }
  return { background: '#ca8a04', borderColor: '#ffffff' }
}

/** One marker per filled stop, ordered A → B → C … */
export function RouteStopsMarkers() {
  const routeStops = useRouteStore((s) => s.routeStops)
  const total = routeStops.length

  return (
    <>
      {routeStops.map((row, index) => {
        const p = row.place
        if (!p) return null
        const { background, borderColor } = pinColors(index, total)

        return (
          <AdvancedMarker
            key={row.id}
            position={{ lat: p.lat, lng: p.lng }}
            title={`${rowLabel(index)} · ${p.name}`}
          >
            <Pin
              background={background}
              borderColor={borderColor}
              glyphColor="#ffffff"
              glyph={rowLabel(index)}
            />
          </AdvancedMarker>
        )
      })}
    </>
  )
}
