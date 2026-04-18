import { AdvancedMarker, Pin } from '@vis.gl/react-google-maps'
import { useFleetStore } from '../../stores/fleetStore'

function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (parts.length >= 2) {
    return (parts[0]![0]! + parts[1]![0]!).toUpperCase()
  }
  return name.slice(0, 2).toUpperCase()
}

function statusColor(status: string): string {
  if (status === 'charging') return '#22c55e'
  if (status === 'online') return '#2563eb'
  return '#64748b'
}

export function FleetVehicleMarkers() {
  const vehicles = useFleetStore((s) => s.vehicles)
  return (
    <>
      {vehicles.map((v) => {
        const loc = v.lastSeenLocation
        if (
          !loc ||
          !Number.isFinite(loc.lat) ||
          !Number.isFinite(loc.lng)
        ) {
          return null
        }
        const bg = statusColor(v.connectionStatus)
        return (
          <AdvancedMarker key={v.vin} position={loc} title={v.name}>
            <Pin
              background={bg}
              borderColor="#ffffff"
              glyphColor="#ffffff"
              glyph={initials(v.name)}
              scale={1.05}
            />
          </AdvancedMarker>
        )
      })}
    </>
  )
}
