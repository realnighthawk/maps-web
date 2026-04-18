import type { LatLng, RoutePlanRequest, RoutePlanResponse } from './contract/routePlan'
import type { Trip } from './types'

/**
 * maps-engine `fleet.TripRow` JSON (no `json` struct tags → PascalCase keys).
 * Nested request/plan are stored as JSON objects in the row.
 */
type RawTripRow = {
  ID?: string
  id?: string
  RequestJSON?: unknown
  request_json?: unknown
  PlanJSON?: unknown
  plan_json?: unknown
  CreatedAt?: string
  created_at?: string
  Status?: string
}

function parseJsonObject<T>(v: unknown): T | null {
  if (v == null) return null
  if (typeof v === 'string') {
    try {
      return JSON.parse(v) as T
    } catch {
      return null
    }
  }
  if (typeof v === 'object') return v as T
  return null
}

function isLatLng(v: unknown): v is LatLng {
  if (!v || typeof v !== 'object') return false
  const o = v as Record<string, unknown>
  return (
    typeof o.lat === 'number' &&
    Number.isFinite(o.lat) &&
    typeof o.lng === 'number' &&
    Number.isFinite(o.lng)
  )
}

export function normalizeTripRow(row: unknown): Trip | null {
  if (!row || typeof row !== 'object') return null
  const r = row as RawTripRow
  const id = (r.ID ?? r.id ?? '').trim()
  if (!id) return null

  const req = parseJsonObject<RoutePlanRequest>(r.RequestJSON ?? r.request_json)
  if (!req || !isLatLng(req.origin) || !isLatLng(req.destination)) return null

  const plan = parseJsonObject<RoutePlanResponse>(r.PlanJSON ?? r.plan_json)
  const route = plan?.route
  const cost = plan?.cost

  const createdRaw = r.CreatedAt ?? r.created_at
  const createdAt =
    typeof createdRaw === 'string' && createdRaw.length > 0
      ? createdRaw
      : new Date().toISOString()

  const totalDistanceMeters =
    route != null && Number.isFinite(route.totalDistanceKm)
      ? route.totalDistanceKm * 1000
      : 0
  const totalDurationSeconds =
    route != null && Number.isFinite(route.totalDurationSec)
      ? route.totalDurationSec
      : 0
  const totalCostDollars =
    cost != null && Number.isFinite(cost.totalCost) ? cost.totalCost : 0

  return {
    id,
    createdAt,
    origin: req.origin,
    destination: req.destination,
    totalDistanceMeters,
    totalDurationSeconds,
    totalCostDollars,
  }
}

export function normalizeTripsResponse(rows: unknown): Trip[] {
  if (!Array.isArray(rows)) return []
  return rows.map(normalizeTripRow).filter((t): t is Trip => t !== null)
}
