import { useMemo } from 'react'
import type { Drive } from '../../api/journeys'
import { useDriveRoute, useDriveSensors, useDriveSeries } from '../../hooks/useDrives'
import { SPEED_SERIES, useDriveStore } from '../../stores/driveStore'
import {
  formatDriveTime,
  formatMiles,
  formatMph,
  formatReading,
  groupSensors,
  kmToMiles,
} from '../../utils/drives'
import { SensorChart } from './SensorChart'

interface Props {
  drive: Drive
  vehicle: string
  onBack: () => void
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-slate-100 px-3 py-2 dark:bg-slate-800">
      <div className="text-sm font-semibold text-slate-900 dark:text-slate-100">{value}</div>
      <div className="text-[11px] text-slate-500 dark:text-slate-400">{label}</div>
    </div>
  )
}

/** One drive in full: its numbers, a chart of any sensor it recorded, and the list of everything it captured. */
export function DriveDetail({ drive, vehicle, onBack }: Props) {
  const pid = useDriveStore((s) => s.selectedPid)
  const selectPid = useDriveStore((s) => s.selectPid)
  const route = useDriveRoute(drive.id)
  const sensors = useDriveSensors(drive.id)
  const isSpeed = pid === SPEED_SERIES
  const series = useDriveSeries(drive.id, isSpeed ? null : pid)

  const groups = useMemo(() => groupSensors(sensors.data ?? []), [sensors.data])
  const sensor = (sensors.data ?? []).find((s) => s.pid === pid)

  // Speed is always available (it is on every observation); other sensors come from their stored series.
  const chart = isSpeed
    ? {
        title: 'Speed',
        unit: 'mph',
        points: (route.data ?? []).map((p) => ({ time: p.time, value: kmToMiles(p.speed_kmh) })),
        loading: route.isLoading,
      }
    : {
        title: sensor?.label || pid,
        unit: sensor?.unit ?? '',
        points: series.data ?? [],
        loading: series.isLoading,
      }

  const start = new Date(drive.started_at)
  return (
    <div className="space-y-4">
      <div className="flex items-start gap-3">
        <button
          type="button"
          onClick={onBack}
          aria-label="Back to all drives"
          className="mt-0.5 rounded-full border border-slate-200 px-2.5 py-1 text-sm text-slate-600 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800"
        >
          ←
        </button>
        <div className="min-w-0">
          <h2 className="truncate text-lg font-semibold text-slate-900 dark:text-slate-100">
            {start.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })}
          </h2>
          <p className="truncate text-sm text-slate-500 dark:text-slate-400">
            {start.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })} · {vehicle}
            {drive.status === 'ACTIVE' ? ' · recording' : drive.status === 'INTERRUPTED' ? ' · ended unexpectedly' : ''}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2">
        <Stat label="Distance" value={formatMiles(drive.distance_km)} />
        <Stat label="Time" value={formatDriveTime(drive.duration_sec)} />
        <Stat label="Average" value={formatMph(drive.avg_speed_kmh)} />
        <Stat label="Top speed" value={formatMph(drive.max_speed_kmh)} />
        <Stat label="Readings" value={drive.observations.toLocaleString('en-US')} />
        <Stat label="Sensors" value={sensors.data ? String(sensors.data.length) : '—'} />
      </div>

      <SensorChart {...chart} />

      <div>
        <h3 className="mb-1 text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          Everything captured
        </h3>
        <p className="mb-2 text-xs text-slate-500 dark:text-slate-400">Choose a reading to chart it.</p>
        {sensors.isLoading && <p className="text-sm text-slate-500">Loading…</p>}
        {sensors.isError && <p className="text-sm text-red-600 dark:text-red-400">Could not load the readings.</p>}
        {groups.map((g) => (
          <section key={g.title} className="mb-3">
            <h4 className="mb-1 text-sm font-semibold text-slate-800 dark:text-slate-200">{g.title}</h4>
            <ul className="divide-y divide-slate-100 rounded-xl border border-slate-200 dark:divide-slate-800 dark:border-slate-700">
              {g.sensors.map((s) => {
                const on = s.pid === pid
                return (
                  <li key={s.pid}>
                    <button
                      type="button"
                      onClick={() => selectPid(s.pid)}
                      aria-pressed={on}
                      className={`flex w-full items-center justify-between gap-3 px-3 py-2 text-left text-sm transition ${
                        on ? 'bg-blue-50 dark:bg-blue-950/40' : 'hover:bg-slate-50 dark:hover:bg-slate-800/60'
                      }`}
                    >
                      <span className="min-w-0 truncate text-slate-800 dark:text-slate-200">{s.label || s.pid}</span>
                      <span className="shrink-0 text-xs tabular-nums text-slate-500 dark:text-slate-400">
                        {s.min === s.max
                          ? `${formatReading(s.min, s.label)}`
                          : `${formatReading(s.min, s.label)} – ${formatReading(s.max, s.label)}`}
                        {s.unit ? ` ${s.unit}` : ''}
                      </span>
                    </button>
                  </li>
                )
              })}
            </ul>
          </section>
        ))}
        {sensors.data && sensors.data.length === 0 && (
          <p className="text-sm text-slate-500 dark:text-slate-400">This drive recorded no sensor readings.</p>
        )}
      </div>
    </div>
  )
}
