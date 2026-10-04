import { chartGeometry, formatReading } from '../../utils/drives'
import { formatClock } from '../../utils/format'

interface Props {
  title: string
  unit: string
  /** Time-ordered points. */
  points: { time: string; value: number }[]
  loading?: boolean
}

/** One sensor over a drive: a line with its range and the start and end times. */
export function SensorChart({ title, unit, points, loading }: Props) {
  const W = 320
  const H = 110
  const g = chartGeometry(points.map((p) => p.value), W, H, 6)
  const avg = points.length ? points.reduce((a, p) => a + p.value, 0) / points.length : 0
  const u = unit ? ` ${unit}` : ''

  return (
    <div className="rounded-xl border border-slate-200 p-3 dark:border-slate-700">
      <div className="flex items-baseline justify-between gap-2">
        <h4 className="truncate text-sm font-semibold text-slate-900 dark:text-slate-100">{title}</h4>
        {points.length > 0 && (
          <span className="shrink-0 text-xs text-slate-500 dark:text-slate-400">
            avg {formatReading(avg)}
            {u}
          </span>
        )}
      </div>
      {points.length === 0 ? (
        <p className="py-8 text-center text-sm text-slate-500">{loading ? 'Loading…' : 'No readings.'}</p>
      ) : (
        <>
          <svg
            viewBox={`0 0 ${W} ${H}`}
            className="mt-2 h-28 w-full"
            role="img"
            aria-label={`${title}: from ${formatReading(g.min)} to ${formatReading(g.max)}${u}`}
          >
            <path d={g.area} className="fill-blue-600/10 dark:fill-blue-400/10" />
            <path d={g.line} fill="none" strokeWidth={2} strokeLinejoin="round" className="stroke-blue-600 dark:stroke-blue-400" />
          </svg>
          <div className="mt-1 flex justify-between text-[11px] text-slate-500 dark:text-slate-400">
            <span>{formatClock(new Date(points[0].time))}</span>
            <span>
              {formatReading(g.min)} – {formatReading(g.max)}
              {u}
            </span>
            <span>{formatClock(new Date(points[points.length - 1].time))}</span>
          </div>
        </>
      )}
    </div>
  )
}
