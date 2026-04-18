import { useQuery } from '@tanstack/react-query'
import { getTrips } from '../../api/fleet'
import { TripRow } from './TripRow'

export function TripsView() {
  const { data, isLoading, isError } = useQuery({
    queryKey: ['trips'],
    queryFn: getTrips,
  })

  return (
    <div className="pointer-events-auto w-full max-w-sm rounded-2xl border border-slate-200/80 bg-white/95 p-4 shadow-xl backdrop-blur-sm dark:border-slate-700/80 dark:bg-slate-900/95">
      <h2 className="text-lg font-semibold text-slate-900 dark:text-slate-100">
        Trips
      </h2>
      {isLoading && (
        <p className="mt-4 text-sm text-slate-500">Loading trips…</p>
      )}
      {isError && (
        <p className="mt-4 text-sm text-red-600 dark:text-red-400">
          Could not load trips.
        </p>
      )}
      {!isLoading && !isError && data && data.length === 0 && (
        <p className="mt-4 text-sm text-slate-600 dark:text-slate-300">
          No trips yet. Plan your first route!
        </p>
      )}
      {data && data.length > 0 && (
        <ul className="mt-4 space-y-2">
          {data.map((t) => (
            <TripRow key={t.id} trip={t} />
          ))}
        </ul>
      )}
    </div>
  )
}
