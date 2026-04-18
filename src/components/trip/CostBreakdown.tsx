import { formatCurrency } from '../../utils/format'
import type { RoutePlanCost } from '../../api/contract/routePlan'

interface CostBreakdownProps {
  cost: RoutePlanCost
}

export function CostBreakdown({ cost }: CostBreakdownProps) {
  const homeEq = cost.ev?.equivHomeCost ?? 0

  return (
    <div className="space-y-1.5 text-sm">
      <Row
        label="Paid at stops (charging / fuel)"
        value={formatCurrency(cost.stopSessionCost)}
      />
      {homeEq > 0 ? (
        <Row
          label="Home electricity equivalent (segment kWh)"
          value={formatCurrency(homeEq)}
        />
      ) : null}
      <Row
        label="Time at stops"
        value={`${Math.round(cost.timeAtStopsMin)} min`}
      />
      {cost.stopCosts.map((sc) => (
        <Row
          key={sc.stopName + sc.timeMin}
          label={sc.stopName}
          value={`${formatCurrency(sc.cost)} · ${Math.round(sc.timeMin)} min`}
        />
      ))}
      <div className="flex justify-between border-t border-slate-200 pt-2 font-semibold dark:border-slate-700">
        <span>Total</span>
        <span className="tabular-nums">{formatCurrency(cost.totalCost)}</span>
      </div>
      <p className="text-xs text-slate-500 dark:text-slate-400">
        {formatCurrency(cost.perMile)} / mi
      </p>
    </div>
  )
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-2 text-slate-700 dark:text-slate-300">
      <span className="min-w-0 truncate">{label}</span>
      <span className="shrink-0 tabular-nums">{value}</span>
    </div>
  )
}
