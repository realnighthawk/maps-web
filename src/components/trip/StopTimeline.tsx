import { formatClock, formatSoc, socColor } from '../../utils/format'
import type { RoutePlanResponse, RoutePlanStop } from '../../api/contract/routePlan'
import { arrivalEnduranceLabel } from '../../api/contract/routePlanDisplay'
import { formatPlannedStopSummary } from '../../utils/routePlanStops'
import { computeTimelineTimes } from '../../utils/timeline'
import { useMapStore } from '../../stores/mapStore'
import {
  routeEndPlace,
  routeStartPlace,
  useRouteStore,
} from '../../stores/routeStore'

interface StopTimelineProps {
  plan: RoutePlanResponse
}

function isFuelStop(stop: RoutePlanStop): boolean {
  return stop.stopType.toLowerCase() === 'fuel' || stop.ice != null
}

export function StopTimeline({ plan }: StopTimelineProps) {
  const panTo = useMapStore((s) => s.panTo)
  const selectedStopIndex = useRouteStore((s) => s.selectedStopIndex)
  const setSelectedStopIndex = useRouteStore((s) => s.setSelectedStopIndex)
  const routeStops = useRouteStore((s) => s.routeStops)
  const origin = routeStartPlace(routeStops)
  const destination = routeEndPlace(routeStops)
  const times = computeTimelineTimes(plan)
  const middleRows = routeStops.slice(1, -1).filter((r) => r.place != null)

  const focusStop = (stop: RoutePlanStop, index: number) => {
    setSelectedStopIndex(index)
    panTo(stop.location.lat, stop.location.lng, 12)
  }

  // Single schedule source: segment durations + dwells (matches route geometry).
  const destClock = formatClock(times.destArrive)
  const arrivalEnd = arrivalEnduranceLabel(plan)

  return (
    <div className="relative pl-6">
      <div
        className="absolute bottom-2 left-[7px] top-2 w-px bg-slate-200 dark:bg-slate-600"
        aria-hidden
      />
      <ul className="space-y-4">
        <li className="relative">
          <Dot kind="origin" />
          <div className="pl-4">
            <div className="text-xs font-medium text-slate-500 dark:text-slate-400">
              Depart
            </div>
            <div className="font-medium text-slate-900 dark:text-slate-100">
              {origin?.name || 'Origin'}
            </div>
            <div className="text-xs text-slate-500 dark:text-slate-400">
              {formatClock(times.originDepart)}
            </div>
          </div>
        </li>

        {middleRows.map((row) => {
          const psi = row.planStopIndex
          const hasPlanStop =
            row.fromPlan === true &&
            typeof psi === 'number' &&
            psi >= 0 &&
            psi < plan.stops.length
          const stop = hasPlanStop ? plan.stops[psi]! : null
          if (stop && hasPlanStop) {
            const t = times.stops[psi]
            const selected = selectedStopIndex === psi
            const fuel = isFuelStop(stop)
            const arrFuel = stop.ice?.arrivalFuelLevel ?? 0
            const depFuel = stop.ice?.departureFuelLevel ?? 0
            const arrEv = stop.ev?.arrivalSoC ?? 0
            const depEv = stop.ev?.departureSoC ?? 0
            return (
              <li key={row.id} className="relative">
                <Dot kind="charger" active={selected} />
                <button
                  type="button"
                  onClick={() => focusStop(stop, psi)}
                  className={`w-full rounded-lg pl-4 text-left transition ${
                    selected
                      ? 'bg-blue-50 ring-1 ring-blue-200 dark:bg-blue-950/40 dark:ring-blue-800'
                      : 'hover:bg-slate-50 dark:hover:bg-slate-800/60'
                  }`}
                >
                  <div className="text-xs font-medium text-slate-500 dark:text-slate-400">
                    {formatPlannedStopSummary(stop)}
                  </div>
                  <div className="font-medium text-slate-900 dark:text-slate-100">
                    {row.place!.name}
                  </div>
                  <div className="text-xs text-slate-500 dark:text-slate-400">
                    {t ? (
                      <>
                        {formatClock(t.arrive)} → {formatClock(t.depart)}
                      </>
                    ) : null}
                  </div>
                  <div className="mt-0.5 text-xs">
                    {fuel ? (
                      <>
                        <span className={socColor(arrFuel)}>
                          Arr {formatSoc(arrFuel)}
                        </span>
                        <span className="text-slate-400"> · </span>
                        <span className={socColor(depFuel)}>
                          Dep {formatSoc(depFuel)}
                        </span>
                      </>
                    ) : stop.ev ? (
                      <>
                        <span className={socColor(arrEv)}>
                          Arr {formatSoc(arrEv)}
                        </span>
                        <span className="text-slate-400"> · </span>
                        <span className={socColor(depEv)}>
                          Dep {formatSoc(depEv)}
                        </span>
                      </>
                    ) : null}
                  </div>
                </button>
              </li>
            )
          }
          return (
            <li key={row.id} className="relative">
              <Dot kind="waypoint" />
              <div className="pl-4">
                <div className="text-xs font-medium text-slate-500 dark:text-slate-400">
                  Via
                </div>
                <div className="font-medium text-slate-900 dark:text-slate-100">
                  {row.place!.name}
                </div>
              </div>
            </li>
          )
        })}

        <li className="relative">
          <Dot kind="dest" />
          <div className="pl-4">
            <div className="text-xs font-medium text-slate-500 dark:text-slate-400">
              Arrive
            </div>
            <div className="font-medium text-slate-900 dark:text-slate-100">
              {destination?.name || 'Destination'}
            </div>
            <div className="text-xs text-slate-500 dark:text-slate-400">
              {destClock}
              {arrivalEnd ? ` · ${arrivalEnd}` : ''}
            </div>
          </div>
        </li>
      </ul>
    </div>
  )
}

function Dot({
  kind,
  active,
}: {
  kind: 'origin' | 'charger' | 'dest' | 'waypoint' | 'passThrough'
  active?: boolean
}) {
  const base =
    'absolute left-0 top-1.5 z-[1] flex h-3.5 w-3.5 items-center justify-center border-2 border-white dark:border-slate-900'
  if (kind === 'origin') {
    return (
      <span
        className={`${base} rounded-full bg-slate-900 dark:bg-slate-100`}
        aria-hidden
      />
    )
  }
  if (kind === 'dest') {
    return (
      <span className={`${base} rounded-sm bg-red-500`} aria-hidden />
    )
  }
  if (kind === 'waypoint') {
    return (
      <span
        className={`${base} rotate-45 border-amber-500 bg-amber-400/40 dark:border-amber-400 dark:bg-amber-500/25`}
        aria-hidden
      />
    )
  }
  if (kind === 'passThrough') {
    return (
      <span
        className={`${base} rounded-full border-slate-300 bg-slate-100 dark:border-slate-500 dark:bg-slate-700`}
        aria-hidden
      />
    )
  }
  return (
    <span
      className={`${base} rounded-full ${
        active ? 'scale-110 bg-blue-600' : 'bg-blue-500'
      }`}
      aria-hidden
    />
  )
}
