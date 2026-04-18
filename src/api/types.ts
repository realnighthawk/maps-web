// Route planning wire types: use `./contract/routePlan` (maps-engine `route_plan.go`).

import type { LatLng } from './contract/routePlan'

export type { LatLng }

// ── Fleet / trips / settings ────────────────────────────────────────────────
// Not backed by maps-engine HTTP API until those endpoints exist; shapes are UI-only.

export type ConnectionStatus = 'online' | 'offline' | 'charging'
export type DataSource = 'OBD' | 'FordPass' | 'manual'

export interface VehicleStatus {
  vin: string
  name: string
  /** From fleet API: EV, PHEV, ICE, etc. */
  drivetrain: string
  stateOfChargePercent: number | null
  fuelPercent: number | null
  /** EPA-style full-charge range when known; omit from UI when null. */
  estimatedRangeKm: number | null
  connectionStatus: ConnectionStatus
  dataSource: DataSource
  lastSeenLocation: LatLng | null
  /** RFC3339 when known; empty means never updated / unknown. */
  lastUpdatedAt: string
}

/** Normalized from GET /trips (`TripRow` + embedded request/plan JSON). */
export interface Trip {
  id: string
  createdAt: string
  origin: LatLng
  destination: LatLng
  totalDistanceMeters: number
  totalDurationSeconds: number
  totalCostDollars: number
}

/** GET/PUT /users/me (maps-engine). */
export interface UserMe {
  id: string
  display_name: string
  email: string
  active_vehicle_vin?: string
  home_electricity_rate_per_kwh: number
  min_fuel_percent: number
  fuel_price_per_liter: number
}

export interface VehicleDetails {
  vin: string
  name: string
  batteryCapacityKwh?: number
  estimatedRangeKm?: number
  connectorTypes?: string[]
  fuelTankLiters?: number
}
