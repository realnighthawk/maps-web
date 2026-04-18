import { AdvancedMarker, AdvancedMarkerAnchorPoint } from '@vis.gl/react-google-maps'
import type { RoutePlanStop } from '../../api/contract/routePlan'

interface ChargerMarkerProps {
  stop: RoutePlanStop
  index: number
  selected: boolean
  onSelect: () => void
}

export function ChargerMarker({
  stop,
  index,
  selected,
  onSelect,
}: ChargerMarkerProps) {
  const label = `${stop.name} — ${Math.round(stop.stopDurationMin)} min`
  const size = selected ? 22 : 18
  return (
    <AdvancedMarker
      position={stop.location}
      title={label}
      onClick={onSelect}
      zIndex={selected ? 100 + index : 10 + index}
      anchorPoint={AdvancedMarkerAnchorPoint.CENTER}
    >
      <div
        style={{
          width: size,
          height: size,
          borderRadius: '50%',
          background: selected ? '#1d4ed8' : '#2563eb',
          border: '2px solid #ffffff',
          boxShadow: '0 1px 3px rgba(0,0,0,0.25)',
        }}
      />
    </AdvancedMarker>
  )
}
