import type { DayStat } from '../../api/journeys'
import { formatMiles } from '../../utils/drives'

/** Distance driven per day. Empty days stay on the axis so gaps read as gaps. */
export function DistanceBars({ days }: { days: DayStat[] }) {
  const W = 320
  const H = 72
  const max = Math.max(...days.map((d) => d.distance_km), 0.001)
  const slot = W / Math.max(days.length, 1)
  const bar = Math.max(2, slot * 0.7)
  const label = (iso: string) =>
    new Date(`${iso}T12:00:00`).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })

  return (
    <div>
      <svg
        viewBox={`0 0 ${W} ${H}`}
        className="h-20 w-full"
        role="img"
        aria-label={`Distance driven per day over the last ${days.length} days`}
      >
        {days.map((d, i) => {
          const h = d.distance_km > 0 ? Math.max(3, (d.distance_km / max) * (H - 6)) : 1.5
          return (
            <rect
              key={d.date}
              x={i * slot + (slot - bar) / 2}
              y={H - h}
              width={bar}
              height={h}
              rx={Math.min(2, bar / 2)}
              className={d.distance_km > 0 ? 'fill-blue-600 dark:fill-blue-400' : 'fill-slate-200 dark:fill-slate-700'}
            >
              <title>{`${label(d.date)}: ${formatMiles(d.distance_km)}, ${d.journeys} drive${d.journeys === 1 ? '' : 's'}`}</title>
            </rect>
          )
        })}
      </svg>
      <div className="mt-1 flex justify-between text-[11px] text-slate-500 dark:text-slate-400">
        <span>{days.length ? label(days[0].date) : ''}</span>
        <span>Today</span>
      </div>
    </div>
  )
}
