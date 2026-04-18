import type { RoutePlanStop } from '../api/contract/routePlan'
import { formatCurrency } from './format'

function isFuelStop(stop: RoutePlanStop): boolean {
  return stop.stopType.toLowerCase() === 'fuel' || stop.ice != null
}

/** One-line summary aligned with the trip timeline row. */
export function formatPlannedStopSummary(stop: RoutePlanStop): string {
  const parts = [
    stop.stopType,
    `${Math.round(stop.stopDurationMin)} min`,
    formatCurrency(stop.energyCost),
  ]
  const kw = stop.ev?.chargePowerKw ?? 0
  if (!isFuelStop(stop) && kw > 0) {
    parts.push(`${Math.round(kw)} kW`)
  }
  return parts.join(' · ')
}

/** Ordered indices for timeline / map: by segment progress, then stable tie-breaker. */
export function routePlanStopDisplayOrder(stops: RoutePlanStop[]): number[] {
  return stops
    .map((_, i) => i)
    .sort((a, b) => {
      const sa = stops[a]?.segmentIndex ?? 0
      const sb = stops[b]?.segmentIndex ?? 0
      if (sa !== sb) return sa - sb
      return a - b
    })
}
