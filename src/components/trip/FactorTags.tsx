import type {
  RoutePlanConsumption,
  RoutePlanRoute,
} from '../../api/contract/routePlan'
import { consumptionModelTags } from '../../api/contract/routePlanDisplay'

interface FactorTagsProps {
  route: RoutePlanRoute
  consumption: RoutePlanConsumption
}

export function FactorTags({ route, consumption }: FactorTagsProps) {
  const confPct =
    consumption.confidence <= 1
      ? consumption.confidence * 100
      : consumption.confidence
  const tags: string[] = []
  if (route.trafficConditions?.trim()) {
    tags.push(`Traffic: ${route.trafficConditions}`)
  }
  tags.push(...consumptionModelTags(consumption))
  tags.push(`Model confidence ${confPct.toFixed(0)}%`)

  return (
    <div className="flex flex-wrap gap-1.5">
      {tags.map((t) => (
        <span
          key={t}
          className="rounded-full bg-slate-100 px-2 py-0.5 text-[11px] text-slate-600 dark:bg-slate-800 dark:text-slate-300"
        >
          {t}
        </span>
      ))}
    </div>
  )
}
