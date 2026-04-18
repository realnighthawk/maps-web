import { useCallback } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { RoutePlanRequest } from '../api/contract/routePlan'
import { planRoute } from '../api/routes'
import { getUserMe } from '../api/fleet'
import { ApiError } from '../api/client'
import { getFleetStatus, getVehicleDetail } from '../api/vehicles'
import {
  routeEndPlace,
  routeStartPlace,
  useRouteStore,
  userWaypointRows,
} from '../stores/routeStore'

const DEFAULT_DEPARTURE_SOC = 80
const DEFAULT_BATTERY_TEMP_C = 25
const DEFAULT_FUEL_PERCENT = 75
const DEFAULT_SPEED_KMH = 0

function parseStoredLocation(
  loc: unknown,
): { lat: number; lng: number } | null {
  if (!loc || typeof loc !== 'object') return null
  const o = loc as Record<string, unknown>
  if (typeof o.lat !== 'number' || typeof o.lng !== 'number') return null
  if (!Number.isFinite(o.lat) || !Number.isFinite(o.lng)) return null
  if (o.lat === 0 && o.lng === 0) return null
  return { lat: o.lat, lng: o.lng }
}

function buildRoutePlanCurrentState(
  profileDrivetrain: string,
  state: Record<string, unknown> | undefined,
  origin: { lat: number; lng: number },
): RoutePlanRequest['currentState'] {
  const dt = profileDrivetrain.toUpperCase()
  const speedKmh =
    typeof state?.speed_kph === 'number' && Number.isFinite(state.speed_kph)
      ? state.speed_kph
      : DEFAULT_SPEED_KMH
  const location = parseStoredLocation(state?.location) ?? origin

  if (dt === 'ICE') {
    const fuelLevelPercent =
      typeof state?.fuel_level === 'number' &&
      Number.isFinite(state.fuel_level)
        ? state.fuel_level
        : DEFAULT_FUEL_PERCENT
    return {
      speedKmh,
      location,
      ice: { fuelLevelPercent },
    }
  }

  const soc =
    typeof state?.state_of_charge === 'number' &&
    Number.isFinite(state.state_of_charge)
      ? state.state_of_charge
      : DEFAULT_DEPARTURE_SOC
  const batteryTempC =
    typeof state?.battery_temp_c === 'number' &&
    Number.isFinite(state.battery_temp_c)
      ? state.battery_temp_c
      : DEFAULT_BATTERY_TEMP_C
  return {
    speedKmh,
    location,
    ev: { soc, batteryTempC },
  }
}

export function useRoutePlanner() {
  const queryClient = useQueryClient()
  const routeStops = useRouteStore((s) => s.routeStops)
  const setPlan = useRouteStore((s) => s.setPlan)
  const setPlanning = useRouteStore((s) => s.setPlanning)
  const setPlanErrorMessage = useRouteStore((s) => s.setPlanErrorMessage)
  const clearPlanOnly = useRouteStore((s) => s.clearPlanOnly)

  const { data: userMe } = useQuery({
    queryKey: ['user', 'me'],
    queryFn: getUserMe,
    retry: 1,
    staleTime: 60_000,
  })

  const runPlan = useCallback(async () => {
    const origin = routeStartPlace(routeStops)
    const destination = routeEndPlace(routeStops)
    if (!origin || !destination) return
    const middleAll = routeStops.slice(1, -1)
    if (middleAll.some((r) => r.place == null)) return

    setPlanErrorMessage(null)
    clearPlanOnly()
    setPlanning(true)
    try {
      let vehicleVin = userMe?.active_vehicle_vin?.trim() ?? ''
      if (!vehicleVin) {
        try {
          const fleetRows = await queryClient.fetchQuery({
            queryKey: ['fleet'],
            queryFn: getFleetStatus,
          })
          const sorted = [...fleetRows].sort((a, b) =>
            a.vin.localeCompare(b.vin),
          )
          vehicleVin = sorted[0]?.vin?.trim() ?? ''
        } catch {
          vehicleVin = ''
        }
      }
      if (!vehicleVin) {
        setPlanErrorMessage(
          'Onboard at least one vehicle under Fleet before planning a route.',
        )
        setPlanning(false)
        return
      }
      const waypoints = userWaypointRows(routeStops)
        .map((r) => r.place)
        .filter((p): p is NonNullable<typeof p> => p != null)

      let currentState: RoutePlanRequest['currentState']
      try {
        const detail = await queryClient.fetchQuery({
          queryKey: ['vehicle', vehicleVin],
          queryFn: () => getVehicleDetail(vehicleVin),
        })
        currentState = buildRoutePlanCurrentState(
          detail.profile.drivetrain ?? '',
          detail.state,
          { lat: origin.lat, lng: origin.lng },
        )
      } catch {
        currentState = buildRoutePlanCurrentState(
          'EV',
          undefined,
          { lat: origin.lat, lng: origin.lng },
        )
      }

      const res = await planRoute({
        vehicleVin,
        origin: { lat: origin.lat, lng: origin.lng },
        destination: { lat: destination.lat, lng: destination.lng },
        ...(waypoints.length > 0
          ? {
              waypoints: waypoints.map((p) => ({
                lat: p.lat,
                lng: p.lng,
              })),
            }
          : {}),
        currentState,
      })
      setPlan(res)
    } catch (e) {
      if (e instanceof ApiError) {
        setPlanErrorMessage(e.message)
      } else {
        setPlanErrorMessage("Couldn't reach the server")
      }
    } finally {
      setPlanning(false)
    }
  }, [
    queryClient,
    routeStops,
    userMe?.active_vehicle_vin,
    setPlan,
    setPlanning,
    setPlanErrorMessage,
    clearPlanOnly,
  ])

  return { runPlan }
}
