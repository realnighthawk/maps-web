import type { VehicleStateWire } from './vehicles'

function num(v: unknown, fallback: number): number {
  if (typeof v === 'number' && Number.isFinite(v)) return v
  return fallback
}

function numOpt(v: unknown): number | undefined {
  if (typeof v === 'number' && Number.isFinite(v)) return v
  return undefined
}

function bool(v: unknown): boolean {
  return v === true
}

/**
 * Builds a full `VehicleStateWire` for PUT /vehicles/{vin}/state from the last
 * API snapshot (maps-engine replaces the whole row on save).
 */
export function vehicleStateWireFromSnapshot(
  snapshot: Record<string, unknown> | VehicleStateWire | null | undefined,
  drivetrain: string,
): VehicleStateWire {
  const s = (snapshot ?? {}) as Record<string, unknown>
  const loc = s.location as Record<string, unknown> | undefined
  const lat = typeof loc?.lat === 'number' ? loc.lat : 0
  const lng = typeof loc?.lng === 'number' ? loc.lng : 0
  const dt = drivetrain.toUpperCase()
  const now = Math.floor(Date.now() / 1000)

  const base: VehicleStateWire = {
    location: { lat, lng },
    speed_kph: num(s.speed_kph, 0),
    odometer_km: num(s.odometer_km, 0),
    heading: num(s.heading, 0),
    ambient_temp_c: num(s.ambient_temp_c, 0),
    data_source:
      typeof s.data_source === 'string' && s.data_source.length > 0
        ? s.data_source
        : 'manual',
    last_updated_unix: num(s.last_updated_unix, now),
    is_charging: bool(s.is_charging),
    is_plugged_in: bool(s.is_plugged_in),
    engine_on: bool(s.engine_on),
    state_of_charge: numOpt(s.state_of_charge),
    battery_temp_c: numOpt(s.battery_temp_c),
    fuel_level: numOpt(s.fuel_level),
  }

  if (dt === 'ICE') {
    if (base.fuel_level === undefined) base.fuel_level = 75
  } else if (dt === 'EV' || dt === 'PHEV') {
    if (base.state_of_charge === undefined) base.state_of_charge = 80
    if (base.battery_temp_c === undefined) base.battery_temp_c = 25
  }

  return base
}

export function clampPercent(n: number): number {
  if (!Number.isFinite(n)) return 0
  return Math.min(100, Math.max(0, n))
}

export function clampToRange(n: number, min: number, max: number): number {
  if (!Number.isFinite(n)) return min
  return Math.min(max, Math.max(min, n))
}
