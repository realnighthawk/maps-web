import { api } from './client'
import type { RoutePlanRequest, RoutePlanResponse } from './contract/routePlan'

export function planRoute(req: RoutePlanRequest): Promise<RoutePlanResponse> {
  return api.post<RoutePlanResponse>('/route/plan', req)
}
