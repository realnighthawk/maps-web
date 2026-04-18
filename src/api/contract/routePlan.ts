/**
 * Route plan JSON mirrors maps-engine `internal/api/route_plan.go` + `route_plan_contract.go`.
 * Drivetrain-specific fields live under optional `ev` / `ice` objects so clients ignore what they do not use.
 */

export interface LatLng {
  lat: number
  lng: number
}

/** EV departure state (optional nested form). */
export interface RoutePlanEvCurrentState {
  soc: number
  batteryTempC: number
}

/** ICE / PHEV fuel snapshot (reserved for future planner use). */
export interface RoutePlanIceCurrentState {
  fuelLevelPercent: number
}

export interface RoutePlanCurrentState {
  location: LatLng
  speedKmh?: number
  /** Legacy flat EV fields — still accepted when `ev` is omitted. */
  soc?: number
  batteryTempC?: number
  ev?: RoutePlanEvCurrentState
  ice?: RoutePlanIceCurrentState
}

export interface RoutePlanRequest {
  vehicleVin: string
  origin: LatLng
  destination: LatLng
  waypoints?: LatLng[]
  currentState: RoutePlanCurrentState
}

export interface RoutePlanSegment {
  index: number
  start: LatLng
  end: LatLng
  distanceKm: number
  durationSec: number
  elevationGainM: number
  elevationLossM: number
  speedLimitKph: number
  roadType: string
  bearingDegrees: number
}

export interface RoutePlanRoute {
  polyline: string
  totalDistanceKm: number
  totalDurationSec: number
  segments: RoutePlanSegment[]
  trafficConditions: string
}

export interface RoutePlanConsumptionEvTotals {
  totalEnergyKwh: number
}

export interface RoutePlanConsumptionIceTotals {
  totalFuelLiters: number
}

export interface RoutePlanSegmentConsumptionEv {
  energyKwh: number
  projectedSoC: number
}

export interface RoutePlanSegmentConsumptionIce {
  fuelLiters: number
  projectedFuelLevel: number
}

export interface RoutePlanSegmentConsumption {
  segmentIndex: number
  distanceKm: number
  ev?: RoutePlanSegmentConsumptionEv
  ice?: RoutePlanSegmentConsumptionIce
}

export interface RoutePlanConsumption {
  confidence: number
  segmentConsumption: RoutePlanSegmentConsumption[]
  ev?: RoutePlanConsumptionEvTotals
  ice?: RoutePlanConsumptionIceTotals
}

export interface RoutePlanStopEv {
  arrivalSoC: number
  departureSoC: number
  chargePowerKw?: number
}

export interface RoutePlanStopIce {
  arrivalFuelLevel: number
  departureFuelLevel: number
}

export interface RoutePlanStop {
  stopType: string
  name: string
  location: LatLng
  stopDurationMin: number
  /** Paid amount at this stop (charging session or fuel). */
  energyCost: number
  segmentIndex: number
  ev?: RoutePlanStopEv
  ice?: RoutePlanStopIce
}

export interface RoutePlanStopCost {
  stopName: string
  cost: number
  timeMin: number
}

export interface RoutePlanCostEv {
  equivHomeCost: number
}

export interface RoutePlanCost {
  totalCost: number
  perMile: number
  timeAtStopsMin: number
  /** Sum paid at charging / fuel stops (not home-equivalent kWh value). */
  stopSessionCost: number
  stopCosts: RoutePlanStopCost[]
  ev?: RoutePlanCostEv
}

export interface RoutePlanArrivalEv {
  projectedSoC: number
}

export interface RoutePlanArrivalIce {
  projectedFuelLevel: number
}

export interface RoutePlanArrival {
  estimatedTime: string
  ev?: RoutePlanArrivalEv
  ice?: RoutePlanArrivalIce
}

export interface RoutePlanResponse {
  route: RoutePlanRoute
  consumption: RoutePlanConsumption
  stops: RoutePlanStop[]
  cost: RoutePlanCost
  arrival: RoutePlanArrival
  warnings?: string[]
}
