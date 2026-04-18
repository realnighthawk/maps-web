import { useRoutePlanner } from '../../hooks/useRoutePlanner'
import { useRouteStore } from '../../stores/routeStore'
import { PlanButton } from './PlanButton'
import { RouteStopList } from './RouteStopList'

export function SearchPanel() {
  const routeStops = useRouteStore((s) => s.routeStops)
  const plan = useRouteStore((s) => s.plan)
  const isPlanning = useRouteStore((s) => s.isPlanning)
  const { runPlan } = useRoutePlanner()

  const canPlan =
    routeStops.length >= 2 &&
    routeStops.every((r) => r.place != null)

  return (
    <div className="pointer-events-auto w-full max-w-sm rounded-2xl border border-slate-200/80 bg-white/95 p-4 shadow-xl backdrop-blur-sm dark:border-slate-700/80 dark:bg-slate-900/95">
      <p className="mb-3 text-xs text-slate-500 dark:text-slate-400">
        Tap the map (including businesses) to open the pin card with Add stop.
        Google’s own place popup is off on this tab so your route actions show up.
      </p>
      <RouteStopList canPlan={canPlan} onPlan={() => void runPlan()} />
      <PlanButton
        disabled={!canPlan}
        loading={isPlanning}
        hasPlannedRoute={Boolean(plan)}
        onClick={() => void runPlan()}
      />
    </div>
  )
}
