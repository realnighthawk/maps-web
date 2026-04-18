import { api } from './client'
import type { VehicleDetailResponse, VehicleProfileWire } from './vehicleProfile'
import type { LatLng, VehicleDetails, VehicleStatus } from './types'

/** Raw row from `GET /api/v1/fleet/status` (maps-engine). */
export interface FleetVehicleDTO {
  vin: string
  make: string
  model: string
  drivetrain: string
  soc?: number
  fuelLevel?: number
  lat?: number
  lng?: number
  lastUpdated?: string
  estimatedRangeKm?: number
}

function mapFleetDtoToStatus(d: FleetVehicleDTO): VehicleStatus {
  const name = [d.make, d.model].filter(Boolean).join(' ').trim() || d.vin
  const dt = (d.drivetrain || '').toUpperCase()

  let stateOfChargePercent: number | null = null
  let fuelPercent: number | null = null
  if (dt === 'EV' || dt === 'PHEV') {
    if (typeof d.soc === 'number' && Number.isFinite(d.soc)) {
      stateOfChargePercent = d.soc
    }
  } else if (dt === 'ICE') {
    if (typeof d.fuelLevel === 'number' && Number.isFinite(d.fuelLevel)) {
      fuelPercent = d.fuelLevel
    }
  }

  let lastSeenLocation: LatLng | null = null
  if (
    typeof d.lat === 'number' &&
    typeof d.lng === 'number' &&
    Number.isFinite(d.lat) &&
    Number.isFinite(d.lng) &&
    !(d.lat === 0 && d.lng === 0)
  ) {
    lastSeenLocation = { lat: d.lat, lng: d.lng }
  }

  const lastUpdatedAt =
    d.lastUpdated && !Number.isNaN(Date.parse(d.lastUpdated))
      ? d.lastUpdated
      : ''

  let estimatedRangeKm: number | null = null
  if (
    typeof d.estimatedRangeKm === 'number' &&
    Number.isFinite(d.estimatedRangeKm) &&
    d.estimatedRangeKm > 0
  ) {
    estimatedRangeKm = d.estimatedRangeKm
  }

  return {
    vin: d.vin,
    name,
    drivetrain: dt,
    stateOfChargePercent,
    fuelPercent,
    estimatedRangeKm,
    connectionStatus: lastSeenLocation ? 'online' : 'offline',
    dataSource: 'manual',
    lastSeenLocation,
    lastUpdatedAt,
  }
}

export function getFleetStatus(): Promise<VehicleStatus[]> {
  return api
    .get<FleetVehicleDTO[]>('/fleet/status')
    .then((rows) => rows.map(mapFleetDtoToStatus))
}

export interface OnboardFromVinResponse {
  profile: Record<string, unknown>
  warnings: string[]
}

export function onboardVehicleFromVin(
  vin: string,
): Promise<OnboardFromVinResponse> {
  return api
    .post<OnboardFromVinResponse>('/vehicles/from-vin', { vin })
    .then((res) => ({
      ...res,
      warnings: res.warnings ?? [],
    }))
}

export function getVehicleDetail(
  vin: string,
): Promise<VehicleDetailResponse> {
  return api.get<VehicleDetailResponse>(
    `/vehicles/${encodeURIComponent(vin)}`,
  )
}

/** Request body for `PUT /vehicles/{vin}/state` (maps-engine `domain.VehicleState` JSON). */
export interface VehicleStateWire {
  vin?: string
  speed_kph?: number
  odometer_km?: number
  location: { lat: number; lng: number }
  heading?: number
  ambient_temp_c?: number
  data_source?: string
  last_updated_unix?: number
  state_of_charge?: number
  battery_temp_c?: number
  is_charging?: boolean
  is_plugged_in?: boolean
  fuel_level?: number
  engine_on?: boolean
}

export function putVehicleState(
  vin: string,
  body: VehicleStateWire,
): Promise<VehicleStateWire> {
  return api.put<VehicleStateWire>(
    `/vehicles/${encodeURIComponent(vin)}/state`,
    body,
  )
}

export interface TelemetryPointWire {
  time: string
  lat: number
  lng: number
  soc?: number
  batteryTempC?: number
  speedKmh?: number
  fuelLevel?: number
  source?: string
}

export function postVehicleTelemetry(
  vin: string,
  points: TelemetryPointWire[],
): Promise<{ inserted: number }> {
  return api.post<{ inserted: number }>(
    `/vehicles/${encodeURIComponent(vin)}/telemetry`,
    { points },
  )
}

const DEFAULT_SEED_SOC = 80
const DEFAULT_SEED_FUEL_PERCENT = 75
const DEFAULT_SEED_BATTERY_TEMP_C = 25

/**
 * Seeds `vehicle_state_current` after onboard so fleet status and route-merge have a baseline.
 * Location (0,0) is treated as “unknown” by the web UI map mapping.
 */
export function initialVehicleStateAfterOnboard(
  profile: Record<string, unknown>,
): VehicleStateWire {
  const dt = String(profile.drivetrain ?? '').toUpperCase()
  const now = Math.floor(Date.now() / 1000)
  const base: VehicleStateWire = {
    location: { lat: 0, lng: 0 },
    speed_kph: 0,
    odometer_km: 0,
    heading: 0,
    ambient_temp_c: 0,
    data_source: 'manual',
    last_updated_unix: now,
  }
  if (dt === 'ICE') {
    return { ...base, fuel_level: DEFAULT_SEED_FUEL_PERCENT }
  }
  return {
    ...base,
    state_of_charge: DEFAULT_SEED_SOC,
    battery_temp_c: DEFAULT_SEED_BATTERY_TEMP_C,
  }
}

export async function updateVehicleProfile(
  vin: string,
  profile: VehicleProfileWire,
): Promise<VehicleProfileWire> {
  const body = { ...profile, vin }
  return api.put<VehicleProfileWire>(
    `/vehicles/${encodeURIComponent(vin)}`,
    body,
  )
}

/** Canonical values for `POST /vehicles/{vin}/connector-types` (maps-engine domain). */
export const VEHICLE_CONNECTOR_TYPE_VALUES = [
  'CCS',
  'CHAdeMO',
  'J1772',
  'TESLA',
] as const

export type VehicleConnectorTypeValue =
  (typeof VEHICLE_CONNECTOR_TYPE_VALUES)[number]

export function postAppendVehicleConnectorTypes(
  vin: string,
  body: { connector_types: string[] },
): Promise<VehicleProfileWire> {
  return api.post<VehicleProfileWire>(
    `/vehicles/${encodeURIComponent(vin)}/connector-types`,
    body,
  )
}

export async function getVehicle(vin: string): Promise<VehicleDetails> {
  const { profile: p } = await getVehicleDetail(vin)
  const name = [p.make, p.model].filter(Boolean).join(' ').trim() || p.vin
  let estimatedRangeKm: number | undefined
  if (typeof p.epa_range_miles === 'number' && p.epa_range_miles > 0) {
    estimatedRangeKm = p.epa_range_miles / 0.621371
  }
  return {
    vin: p.vin,
    name,
    batteryCapacityKwh: p.battery_capacity_kwh,
    estimatedRangeKm,
    connectorTypes: p.connector_types,
    fuelTankLiters: p.fuel_tank_size_liters,
  }
}
