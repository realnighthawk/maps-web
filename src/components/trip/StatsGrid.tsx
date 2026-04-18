import { formatCurrency, formatDistance, formatDuration } from '../../utils/format'

interface StatsGridProps {
  distanceMeters: number
  durationSeconds: number
  totalCostDollars: number
}

export function StatsGrid({
  distanceMeters,
  durationSeconds,
  totalCostDollars,
}: StatsGridProps) {
  return (
    <div className="grid grid-cols-3 gap-2">
      <StatBox label="Distance" value={formatDistance(distanceMeters)} />
      <StatBox label="Time" value={formatDuration(durationSeconds)} />
      <StatBox label="Cost" value={formatCurrency(totalCostDollars)} />
    </div>
  )
}

function StatBox({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-slate-200 bg-slate-50/80 px-2 py-2 text-center dark:border-slate-700 dark:bg-slate-800/80">
      <div className="text-[10px] font-medium uppercase tracking-wide text-slate-500 dark:text-slate-400">
        {label}
      </div>
      <div className="mt-0.5 text-sm font-semibold tabular-nums text-slate-900 dark:text-slate-100">
        {value}
      </div>
    </div>
  )
}
