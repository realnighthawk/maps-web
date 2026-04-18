/** Mirrors maps-engine `domain.VehicleProfile` JSON tags. */
export interface VehicleProfileWire {
  vin: string
  make: string
  model: string
  year: number
  drivetrain: string
  /** All EV inlet types the vehicle supports (union when searching chargers). */
  connector_types?: string[]
  battery_capacity_kwh?: number
  epa_range_miles?: number
  max_charge_power_kw?: number
  epa_vehicle_id?: number
  fuel_tank_size_liters?: number
  fuel_grade?: string
  epa_mpg_city?: number
  epa_mpg_highway?: number
  /** Minimum destination SoC (%) for routing; omit or 0 = server default (15). */
  planning_min_soc_percent?: number
  /** Target SoC (%) at charging stops; omit or 0 = server default (80). */
  planning_charge_to_percent?: number
}

/** One editable telemetry field from GET /vehicles/{vin} (`live_state_edit`). */
export interface LiveStateEditField {
  key: string
  /** `percent` → slider + clamp; `number` → numeric input. Unknown types are ignored. */
  type: string
  label: string
  value: number
  min?: number
  max?: number
  step?: number
}

export interface LiveStateEditBlock {
  title: string
  subtitle?: string
  fields: LiveStateEditField[]
}

/** GET /vehicles/{vin} response. */
export interface VehicleDetailResponse {
  profile: VehicleProfileWire
  state?: Record<string, unknown>
  /** Server-selected editable state fields for this vehicle (EV vs ICE, etc.). */
  live_state_edit?: LiveStateEditBlock[]
}
