import { formatCurrency, formatDistance, formatDuration } from '../../utils/format'
import type { Trip } from '../../api/types'
import { useTripEndpointLabel } from '../../hooks/useTripEndpointLabel'
import { newRouteStopRow, useRouteStore } from '../../stores/routeStore'
import { useAppStore } from '../../stores/appStore'

interface TripRowProps {
  trip: Trip
}

export function TripRow({ trip }: TripRowProps) {
  const setRouteStops = useRouteStore((s) => s.setRouteStops)
  const clearPlanOnly = useRouteStore((s) => s.clearPlanOnly)
  const setActiveTab = useAppStore((s) => s.setActiveTab)

  const originLabel = useTripEndpointLabel(trip.origin.lat, trip.origin.lng)
  const destLabel = useTripEndpointLabel(trip.destination.lat, trip.destination.lng)

  const onReuse = () => {
    const originName =
      originLabel !== '…' ? originLabel : `${trip.origin.lat.toFixed(4)}, ${trip.origin.lng.toFixed(4)}`
    const destinationName =
      destLabel !== '…'
        ? destLabel
        : `${trip.destination.lat.toFixed(4)}, ${trip.destination.lng.toFixed(4)}`
    setRouteStops([
      newRouteStopRow({
        name: originName,
        lat: trip.origin.lat,
        lng: trip.origin.lng,
      }),
      newRouteStopRow({
        name: destinationName,
        lat: trip.destination.lat,
        lng: trip.destination.lng,
      }),
    ])
    clearPlanOnly()
    setActiveTab('route')
  }

  const date = new Date(trip.createdAt).toLocaleString()

  return (
    <li>
      <button
        type="button"
        onClick={onReuse}
        className="w-full rounded-xl border border-slate-200 bg-white/90 px-3 py-2.5 text-left transition hover:border-blue-300 hover:bg-blue-50/50 dark:border-slate-700 dark:bg-slate-800/80 dark:hover:border-blue-700 dark:hover:bg-blue-950/30"
      >
        <div className="text-xs text-slate-500 dark:text-slate-400">{date}</div>
        <div className="mt-0.5 text-left text-sm font-medium leading-snug text-slate-900 dark:text-slate-100">
          <span className="line-clamp-2">{originLabel}</span>
          <span className="mx-1 text-slate-400">→</span>
          <span className="line-clamp-2">{destLabel}</span>
        </div>
        <div className="mt-1 flex flex-wrap gap-x-3 gap-y-0.5 text-xs text-slate-600 dark:text-slate-300">
          <span>{formatDistance(trip.totalDistanceMeters)}</span>
          <span>{formatDuration(trip.totalDurationSeconds)}</span>
          <span>{formatCurrency(trip.totalCostDollars)}</span>
        </div>
      </button>
    </li>
  )
}
