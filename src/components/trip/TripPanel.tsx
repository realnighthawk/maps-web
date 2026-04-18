import { useRouteStore } from '../../stores/routeStore'
import { StatsGrid } from './StatsGrid'
import { StopTimeline } from './StopTimeline'
import { FactorTags } from './FactorTags'
import { CostBreakdown } from './CostBreakdown'

export function TripPanel() {
  const plan = useRouteStore((s) => s.plan)
  const resetRoutePlanner = useRouteStore((s) => s.resetRoutePlanner)

  if (!plan) return null

  const distanceMeters = plan.route.totalDistanceKm * 1000
  const durationSeconds = Math.round(plan.route.totalDurationSec)

  return (
    <div
      className="pointer-events-auto max-h-[min(560px,calc(100vh-8rem))] w-full max-w-md translate-x-0 overflow-y-auto rounded-2xl border border-slate-200/80 bg-white/95 p-4 shadow-xl backdrop-blur-sm transition-transform duration-300 ease-out dark:border-slate-700/80 dark:bg-slate-900/95 xl:max-h-[min(640px,calc(100vh-6rem))]"
      role="region"
      aria-label="Trip plan"
    >
      <div className="mb-3 flex items-center justify-between gap-2">
        <h2 className="text-lg font-semibold text-slate-900 dark:text-slate-100">
          Trip plan
        </h2>
        <button
          type="button"
          onClick={resetRoutePlanner}
          className="rounded-lg px-3 py-1.5 text-sm font-medium text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
        >
          Clear
        </button>
      </div>
      <StatsGrid
        distanceMeters={distanceMeters}
        durationSeconds={durationSeconds}
        totalCostDollars={plan.cost.totalCost}
      />
      {plan.warnings && plan.warnings.length > 0 && (
        <ul className="mt-3 list-inside list-disc text-xs text-amber-800 dark:text-amber-200">
          {plan.warnings.map((w) => (
            <li key={w}>{w}</li>
          ))}
        </ul>
      )}
      <div className="mt-4">
        <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          Stops
        </h3>
        <StopTimeline plan={plan} />
      </div>
      <div className="mt-4">
        <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          Route
        </h3>
        <FactorTags route={plan.route} consumption={plan.consumption} />
      </div>
      <div className="mt-4">
        <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          Cost
        </h3>
        <CostBreakdown cost={plan.cost} />
      </div>
    </div>
  )
}
