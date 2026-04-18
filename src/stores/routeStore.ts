import { arrayMove } from '@dnd-kit/sortable'
import { create } from 'zustand'
import type { RoutePlanResponse } from '../api/contract/routePlan'
import { routePlanStopDisplayOrder } from '../utils/routePlanStops'

export interface Place {
  name: string
  lat: number
  lng: number
  placeId?: string
}

/** One row in the directions list (first = start, last = destination). */
export interface RouteStopRow {
  id: string
  place: Place | null
  /**
   * Row came from the last successful plan (charging / fuel). Same UI as user stops,
   * but omitted from API `waypoints` so hybrid planning still runs A→B.
   */
  fromPlan?: boolean
  /** Index into `RoutePlanResponse.stops` when `fromPlan`. */
  planStopIndex?: number
}

export function newRouteStopRow(
  place: Place | null = null,
  opts?: { fromPlan?: boolean; planStopIndex?: number },
): RouteStopRow {
  return {
    id: crypto.randomUUID(),
    place,
    fromPlan: opts?.fromPlan,
    planStopIndex: opts?.planStopIndex,
  }
}

/** User-edited middle rows only (excludes optimizer-inserted stops). */
export function userWaypointRows(stops: RouteStopRow[]): RouteStopRow[] {
  if (stops.length < 2) return []
  return stops.slice(1, -1).filter((r) => !r.fromPlan)
}

function stripPlanInsertedStops(rows: RouteStopRow[]): RouteStopRow[] {
  if (rows.length < 2) return rows
  const first = rows[0]!
  const last = rows[rows.length - 1]!
  const middle = rows.slice(1, -1).filter((r) => !r.fromPlan)
  return [first, ...middle, last]
}

function mergePlanIntoRouteStops(
  rows: RouteStopRow[],
  plan: RoutePlanResponse,
): RouteStopRow[] {
  if (rows.length < 2) return rows
  const first = rows[0]!
  const last = rows[rows.length - 1]!
  const userMiddle = rows.slice(1, -1).filter((r) => !r.fromPlan)
  if (!plan.stops.length) {
    return [first, ...userMiddle, last]
  }
  const order = routePlanStopDisplayOrder(plan.stops)
  const planRows = order.map((idx) => {
    const s = plan.stops[idx]!
    return newRouteStopRow(
      {
        name: s.name,
        lat: s.location.lat,
        lng: s.location.lng,
      },
      { fromPlan: true, planStopIndex: idx },
    )
  })
  return [first, ...userMiddle, ...planRows, last]
}

/**
 * Max rows in the list: starting point + up to 25 intermediates + destination
 * (matches maps-engine waypoint cap).
 */
export const MAX_ROUTE_STOPS = 27

export function routeStartPlace(stops: RouteStopRow[]): Place | null {
  return stops[0]?.place ?? null
}

export function routeEndPlace(stops: RouteStopRow[]): Place | null {
  if (stops.length === 0) return null
  return stops[stops.length - 1]?.place ?? null
}

interface RouteState {
  routeStops: RouteStopRow[]
  selectedStopIndex: number | null
  plan: RoutePlanResponse | null
  isPlanning: boolean
  planErrorMessage: string | null
  setStopPlaceAt: (index: number, place: Place | null) => void
  addStopBeforeDestination: () => void
  removeStopAt: (index: number) => void
  reorderStopsByIndex: (fromIndex: number, toIndex: number) => void
  setRouteStops: (stops: RouteStopRow[]) => void
  setSelectedStopIndex: (index: number | null) => void
  setPlan: (plan: RoutePlanResponse | null) => void
  setPlanning: (v: boolean) => void
  setPlanErrorMessage: (message: string | null) => void
  clearPlan: () => void
  clearPlanOnly: () => void
  resetRoutePlanner: () => void
  /** Reverse the full stop list (start ↔ destination, like Google Maps). */
  swapRouteEndpoints: () => void
  /** Staged location from a map tap (committed with `commitMapPickToRoute`). */
  mapPickPreview: Place | null
  mapPickGeocoding: boolean
  setMapPickPreview: (place: Place | null) => void
  setMapPickGeocoding: (v: boolean) => void
  clearMapPickPreview: () => void
  /**
   * Applies staged map pick to the route (destination if empty, else via before
   * destination). Clears preview on success; on max-stops error keeps preview.
   */
  commitMapPickToRoute: () => void
}

export const DEFAULT_ORIGIN: Place = {
  name: 'San Jose, CA',
  lat: 37.3382,
  lng: -121.8863,
}

function initialRouteStops(): RouteStopRow[] {
  return [newRouteStopRow({ ...DEFAULT_ORIGIN }), newRouteStopRow(null)]
}

/** True when the starting point is still the app default (not chosen via search / URL / GPS). */
export function isDefaultOrigin(p: Place | null): boolean {
  if (!p) return false
  return (
    Math.abs(p.lat - DEFAULT_ORIGIN.lat) < 1e-5 &&
    Math.abs(p.lng - DEFAULT_ORIGIN.lng) < 1e-5
  )
}

/** Clear plan metadata and drop optimizer-inserted middle rows (keep user A / vias / B). */
function invalidatePlan(rows: RouteStopRow[]) {
  return {
    routeStops: stripPlanInsertedStops(rows),
    selectedStopIndex: null as number | null,
    plan: null as RoutePlanResponse | null,
    planErrorMessage: null as string | null,
  }
}

type MapPickApplyResult =
  | { routeStops: RouteStopRow[] }
  | { planErrorMessage: string }

function applyMapPickPlace(
  stops: RouteStopRow[],
  place: Place,
): MapPickApplyResult | null {
  const rows = [...stops]
  if (rows.length < 2) return null
  const lastIdx = rows.length - 1
  const destEmpty = rows[lastIdx]?.place == null
  if (destEmpty) {
    rows[lastIdx] = { ...rows[lastIdx], place }
    return { routeStops: rows }
  }
  if (rows.length >= MAX_ROUTE_STOPS) {
    return {
      planErrorMessage:
        'Maximum number of stops reached. Remove a stop to add another from the map.',
    }
  }
  rows.splice(lastIdx, 0, newRouteStopRow(place))
  return { routeStops: rows }
}

export const useRouteStore = create<RouteState>((set) => ({
  routeStops: initialRouteStops(),
  selectedStopIndex: null,
  plan: null,
  isPlanning: false,
  planErrorMessage: null,
  mapPickPreview: null,
  mapPickGeocoding: false,

  setStopPlaceAt: (index, place) =>
    set((s) => {
      const rows = [...s.routeStops]
      if (index < 0 || index >= rows.length) return {}
      if (
        place == null &&
        index > 0 &&
        index < rows.length - 1
      ) {
        rows.splice(index, 1)
        if (rows.length < 2) return {}
        return invalidatePlan(rows)
      }
      const prev = rows[index]!
      rows[index] = {
        ...prev,
        place,
        ...(place != null && prev.fromPlan
          ? { fromPlan: false, planStopIndex: undefined }
          : {}),
      }
      return invalidatePlan(rows)
    }),

  addStopBeforeDestination: () =>
    set((s) => {
      const t = [...s.routeStops]
      if (t.length < 2) return {}
      if (t.length >= MAX_ROUTE_STOPS) return {}
      t.splice(t.length - 1, 0, newRouteStopRow(null))
      return invalidatePlan(t)
    }),

  removeStopAt: (index) =>
    set((s) => {
      if (index <= 0 || index >= s.routeStops.length - 1) return {}
      const rows = s.routeStops.filter((_, i) => i !== index)
      return invalidatePlan(rows)
    }),

  reorderStopsByIndex: (fromIndex, toIndex) =>
    set((s) => {
      if (
        fromIndex < 0 ||
        fromIndex >= s.routeStops.length ||
        toIndex < 0 ||
        toIndex >= s.routeStops.length ||
        fromIndex === toIndex
      ) {
        return {}
      }
      return invalidatePlan(arrayMove(s.routeStops, fromIndex, toIndex))
    }),

  setRouteStops: (stops) =>
    set(() => invalidatePlan(stops)),

  setSelectedStopIndex: (index) => set({ selectedStopIndex: index }),
  setPlan: (plan) =>
    set((s) => {
      if (!plan) {
        return { plan: null, planErrorMessage: null }
      }
      return {
        plan,
        planErrorMessage: null,
        routeStops: mergePlanIntoRouteStops(s.routeStops, plan),
      }
    }),
  setPlanning: (isPlanning) => set({ isPlanning }),
  setPlanErrorMessage: (planErrorMessage) => set({ planErrorMessage }),
  clearPlan: () => set((s) => invalidatePlan(s.routeStops)),
  clearPlanOnly: () =>
    set((s) => ({
      plan: null,
      selectedStopIndex: null,
      planErrorMessage: null,
      routeStops: stripPlanInsertedStops(s.routeStops),
    })),
  resetRoutePlanner: () =>
    set({
      routeStops: initialRouteStops(),
      selectedStopIndex: null,
      plan: null,
      planErrorMessage: null,
      mapPickPreview: null,
      mapPickGeocoding: false,
    }),
  swapRouteEndpoints: () =>
    set((s) => ({
      ...invalidatePlan([...s.routeStops].reverse()),
      mapPickPreview: null,
      mapPickGeocoding: false,
    })),

  setMapPickPreview: (place) => set({ mapPickPreview: place }),
  setMapPickGeocoding: (v) => set({ mapPickGeocoding: v }),
  clearMapPickPreview: () =>
    set({ mapPickPreview: null, mapPickGeocoding: false }),

  commitMapPickToRoute: () =>
    set((s) => {
      if (!s.mapPickPreview) return {}
      const applied = applyMapPickPlace(s.routeStops, s.mapPickPreview)
      if (!applied) return {}
      if ('planErrorMessage' in applied) {
        return { planErrorMessage: applied.planErrorMessage }
      }
      return {
        ...invalidatePlan(applied.routeStops),
        mapPickPreview: null,
        mapPickGeocoding: false,
      }
    }),
}))
