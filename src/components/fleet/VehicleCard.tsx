import type { VehicleStatus } from '../../api/types'

interface VehicleCardProps {
  vehicle: VehicleStatus
  onSelect?: () => void
  /** When set, show active state / “Set active” for route planning. */
  activeVin?: string
  onSetActive?: () => void
  setActiveLoading?: boolean
}

export function VehicleCard({
  vehicle: v,
  onSelect,
  activeVin,
  onSetActive,
  setActiveLoading,
}: VehicleCardProps) {
  const pct = v.stateOfChargePercent ?? v.fuelPercent ?? null
  const subtitle = [v.vin]
    .concat(
      v.estimatedRangeKm != null && v.estimatedRangeKm > 0
        ? [`~${Math.round(v.estimatedRangeKm)} km`]
        : [],
    )
    .join(' · ')
  const isActive =
    activeVin != null && activeVin.trim() !== '' && activeVin.trim() === v.vin

  return (
    <div className="flex w-full overflow-hidden rounded-lg border border-slate-200/90 bg-white/90 dark:border-slate-600/90 dark:bg-slate-800/80">
      <button
        type="button"
        onClick={onSelect}
        className="flex min-w-0 flex-1 items-center gap-3 px-3 py-2 text-left transition hover:bg-white dark:hover:bg-slate-800"
      >
        <div
          className={`h-9 w-1 shrink-0 rounded-full ${
            v.connectionStatus === 'charging'
              ? 'bg-emerald-500'
              : v.connectionStatus === 'online'
                ? 'bg-blue-500'
                : 'bg-slate-300 dark:bg-slate-600'
          }`}
          aria-hidden
        />
        <div className="min-w-0 flex-1">
          <div className="flex min-w-0 items-center gap-2">
            <span className="truncate text-sm font-medium text-slate-900 dark:text-slate-100">
              {v.name}
            </span>
            {isActive && (
              <span className="shrink-0 rounded-md bg-emerald-100 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-200">
                Active
              </span>
            )}
          </div>
          <div className="truncate font-mono text-[10px] text-slate-500 dark:text-slate-400">
            {subtitle}
          </div>
        </div>
        {pct !== null && (
          <div className="shrink-0 text-right">
            <div className="text-sm font-semibold tabular-nums text-slate-800 dark:text-slate-100">
              {Math.round(pct)}%
            </div>
            <div className="mx-auto mt-0.5 h-1 w-10 overflow-hidden rounded-full bg-slate-200 dark:bg-slate-600">
              <div
                className="h-full rounded-full bg-slate-700 dark:bg-slate-300"
                style={{
                  width: `${Math.min(100, Math.max(0, pct))}%`,
                }}
              />
            </div>
          </div>
        )}
        <span
          className="shrink-0 text-slate-400 dark:text-slate-500"
          aria-hidden
        >
          →
        </span>
      </button>
      {onSetActive != null && (
        <div className="flex shrink-0 flex-col justify-center border-l border-slate-200/90 px-2 dark:border-slate-600/90">
          {isActive ? (
            <span
              className="px-1 text-center text-[10px] font-medium text-slate-400 dark:text-slate-500"
              title="Used for new route plans"
            >
              Routes
            </span>
          ) : (
            <button
              type="button"
              disabled={setActiveLoading}
              onClick={(e) => {
                e.stopPropagation()
                onSetActive()
              }}
              className="whitespace-nowrap rounded-md px-2 py-1.5 text-[11px] font-semibold text-slate-700 hover:bg-slate-100 disabled:opacity-50 dark:text-slate-200 dark:hover:bg-slate-700/80"
            >
              {setActiveLoading ? '…' : 'Set active'}
            </button>
          )}
        </div>
      )}
    </div>
  )
}
