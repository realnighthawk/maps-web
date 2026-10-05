import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { getTrips } from '../../api/fleet'
import { useDriveStats, useDrives, useGarage } from '../../hooks/useDrives'
import { useDriveStore, type DaysWindow } from '../../stores/driveStore'
import { describeError } from '../../utils/errors'
import { mergeTrips, type TripFilter } from '../../utils/trips'
import { TripRow } from '../trips/TripRow'
import { formatDriveTime, formatMiles, formatMph, vehicleName } from '../../utils/drives'
import { DistanceBars } from '../drives/DistanceBars'
import { DriveDetail } from '../drives/DriveDetail'
import { DriveRow } from '../drives/DriveRow'

const WINDOWS: DaysWindow[] = [7, 30, 90]

function Total({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-lg font-semibold tabular-nums text-slate-900 dark:text-slate-100">{value}</div>
      <div className="text-[11px] text-slate-500 dark:text-slate-400">{label}</div>
    </div>
  )
}

/**
 * Every trip in one list: the ones your phone recorded and streamed to your own maps-engine (driven) and the routes you
 * planned. Driven trips come with totals and everything they captured.
 */
export function TripsView() {
  const filter = useDriveStore((s) => s.filter)
  const setFilter = useDriveStore((s) => s.setFilter)
  const planned = useQuery({ queryKey: ['trips'], queryFn: getTrips })
  const days = useDriveStore((s) => s.days)
  const setDays = useDriveStore((s) => s.setDays)
  const selectedId = useDriveStore((s) => s.selectedId)
  const select = useDriveStore((s) => s.select)

  const drives = useDrives()
  const stats = useDriveStats(days)
  const garage = useGarage()

  const names = useMemo(() => {
    const byId = new Map((garage.data ?? []).map((v) => [v.id, v]))
    return (id: string) => vehicleName(byId.get(id), id)
  }, [garage.data])

  const selected = selectedId ? drives.data?.find((d) => d.id === selectedId) : undefined
  const st = stats.data
  const items = mergeTrips(drives.data ?? [], planned.data ?? [], filter)
  const loading = drives.isLoading || planned.isLoading
  const failed = drives.isError || planned.isError

  return (
    <div className="pointer-events-auto max-h-[calc(100vh-7.5rem)] w-full max-w-md overflow-y-auto rounded-2xl border border-slate-200/80 bg-white/95 p-4 shadow-xl backdrop-blur-sm dark:border-slate-700/80 dark:bg-slate-900/95">
      {selected ? (
        <DriveDetail drive={selected} vehicle={names(selected.vehicle_id)} onBack={() => select(null)} />
      ) : (
        <div className="space-y-5">
          <div className="flex items-center justify-between gap-3">
            <h2 className="text-lg font-semibold text-slate-900 dark:text-slate-100">Trips</h2>
            <div className="flex gap-1" role="group" aria-label="Time window">
              {WINDOWS.map((w) => (
                <button
                  key={w}
                  type="button"
                  onClick={() => setDays(w)}
                  aria-pressed={days === w}
                  className={`rounded-full px-3 py-1 text-xs font-medium transition ${
                    days === w
                      ? 'bg-slate-900 text-white dark:bg-slate-100 dark:text-slate-900'
                      : 'text-slate-500 hover:text-slate-800 dark:text-slate-400 dark:hover:text-slate-200'
                  }`}
                >
                  {w} days
                </button>
              ))}
            </div>
          </div>

          {filter !== 'planned' && stats.isError && (
            <p className="text-sm text-red-600 dark:text-red-400">{describeError(stats.error, 'totals')}</p>
          )}
          {filter !== 'planned' && st && (
            <section aria-label={`Totals for the last ${days} days`} className="space-y-3">
              <div className="grid grid-cols-3 gap-y-3">
                <Total label="Drives" value={String(st.journeys)} />
                <Total label="Distance" value={formatMiles(st.distance_km)} />
                <Total label="Time driving" value={formatDriveTime(st.duration_sec)} />
                <Total label="Average speed" value={st.journeys ? formatMph(st.avg_speed_kmh) : '—'} />
                <Total label="Top speed" value={st.journeys ? formatMph(st.max_speed_kmh) : '—'} />
              </div>
              <DistanceBars days={st.by_day} />
              {st.by_vehicle.length > 1 && (
                <ul className="space-y-1 text-sm">
                  {st.by_vehicle.map((v) => (
                    <li key={v.vehicle_id} className="flex justify-between text-slate-600 dark:text-slate-300">
                      <span className="truncate">{names(v.vehicle_id)}</span>
                      <span className="shrink-0 tabular-nums">
                        {formatMiles(v.distance_km)} · {v.journeys} drive{v.journeys === 1 ? '' : 's'}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          )}

          <section>
            <div className="mb-2 flex gap-1" role="group" aria-label="Show">
              {(['all', 'driven', 'planned'] as TripFilter[]).map((f) => (
                <button
                  key={f}
                  type="button"
                  onClick={() => setFilter(f)}
                  aria-pressed={filter === f}
                  className={`rounded-full px-3 py-1 text-xs font-medium capitalize transition ${
                    filter === f
                      ? 'bg-slate-900 text-white dark:bg-slate-100 dark:text-slate-900'
                      : 'text-slate-500 hover:text-slate-800 dark:text-slate-400 dark:hover:text-slate-200'
                  }`}
                >
                  {f}
                </button>
              ))}
            </div>
            {loading && <p className="text-sm text-slate-500">Loading trips…</p>}
            {failed && (
              <p className="text-sm text-red-600 dark:text-red-400">
                {describeError(drives.error ?? planned.error, 'trips')}
              </p>
            )}
            {!loading && !failed && items.length === 0 && (
              <p className="text-sm text-slate-600 dark:text-slate-300">
                {filter === 'planned'
                  ? 'No planned trips yet. Plan a route and it appears here.'
                  : 'No trips yet. Plan a route, or start a drive in the app and it appears here as it streams.'}
              </p>
            )}
            {items.length > 0 && (
              <ul className="space-y-2">
                {items.map((i) =>
                  i.kind === 'driven' ? (
                    <DriveRow key={`d-${i.drive.id}`} drive={i.drive} vehicle={names(i.drive.vehicle_id)} onSelect={() => select(i.drive.id)} />
                  ) : (
                    <TripRow key={`p-${i.trip.id}`} trip={i.trip} />
                  ),
                )}
              </ul>
            )}
          </section>
        </div>
      )}
    </div>
  )
}
