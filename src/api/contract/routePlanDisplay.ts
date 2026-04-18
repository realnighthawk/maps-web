import type { RoutePlanConsumption, RoutePlanResponse } from './routePlan'

/** Human-readable energy / fuel summary tags for the route panel. */
export function consumptionModelTags(consumption: RoutePlanConsumption): string[] {
  const tags: string[] = []
  if (consumption.ev) {
    tags.push(`Energy est. ${consumption.ev.totalEnergyKwh.toFixed(1)} kWh`)
  }
  if (consumption.ice) {
    tags.push(`Fuel est. ${consumption.ice.totalFuelLiters.toFixed(2)} L`)
  }
  if (!consumption.ev && !consumption.ice) {
    tags.push('No drivetrain totals (see segments if present)')
  }
  return tags
}

export function arrivalEnduranceLabel(plan: RoutePlanResponse): string | null {
  if (plan.arrival.ev) {
    return `est. SoC ${Math.round(plan.arrival.ev.projectedSoC)}%`
  }
  if (plan.arrival.ice) {
    return `est. fuel ${Math.round(plan.arrival.ice.projectedFuelLevel)}%`
  }
  return null
}
