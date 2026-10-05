import type { Drive } from '../../api/journeys'
import { formatDriveTime, formatMiles, formatMph } from '../../utils/drives'

interface Props {
  drive: Drive
  vehicle: string
  onSelect: () => void
}

export function DriveRow({ drive, vehicle, onSelect }: Props) {
  const start = new Date(drive.started_at)
  const when = `${start.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })} · ${start.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}`
  return (
    <li>
      <button
        type="button"
        onClick={onSelect}
        className="flex w-full items-center justify-between gap-3 rounded-xl border border-slate-200 p-3 text-left transition hover:border-slate-300 hover:bg-slate-50 dark:border-slate-700 dark:hover:border-slate-600 dark:hover:bg-slate-800/60"
      >
        <span className="min-w-0">
          <span className="block truncate text-sm font-medium text-slate-900 dark:text-slate-100">
            <span className="mr-2 rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-emerald-800 dark:bg-emerald-900/50 dark:text-emerald-300">
              Driven
            </span>
            {when}
          </span>
          <span className="block truncate text-xs text-slate-500 dark:text-slate-400">
            {vehicle}
            {drive.status === 'ACTIVE' ? ' · recording' : ''}
          </span>
        </span>
        <span className="shrink-0 text-right">
          <span className="block text-sm font-semibold text-slate-900 dark:text-slate-100">{formatMiles(drive.distance_km)}</span>
          <span className="block text-xs text-slate-500 dark:text-slate-400">
            {formatDriveTime(drive.duration_sec)} · top {formatMph(drive.max_speed_kmh)}
          </span>
        </span>
      </button>
    </li>
  )
}
