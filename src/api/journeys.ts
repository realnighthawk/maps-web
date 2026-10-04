import { api } from './client'

/** A recorded drive with its summary (distance and speeds are computed server-side from the stored readings). */
export interface Drive {
  id: string
  vehicle_id: string
  status: 'ACTIVE' | 'COMPLETED' | 'INTERRUPTED'
  started_at: string
  ended_at?: string
  start_lat?: number
  start_lng?: number
  end_lat?: number
  end_lng?: number
  observations: number
  distance_km: number
  avg_speed_kmh: number
  max_speed_kmh: number
  duration_sec?: number
}

/** One downsampled point of a drive; lat/lng are missing when the phone had no GPS fix. */
export interface DriveSample {
  time: string
  lat?: number
  lng?: number
  speed_kmh: number
}

/** One sensor a drive recorded ("010C" engine rpm, "7E4.4801" a raw battery value, "phone.baro_kpa"...). */
export interface Sensor {
  pid: string
  label: string
  unit: string
  count: number
  min: number
  max: number
  avg: number
}

export interface SeriesPoint {
  time: string
  value: number
}

export interface DayStat {
  date: string
  journeys: number
  distance_km: number
  duration_sec: number
}

export interface VehicleStat {
  vehicle_id: string
  journeys: number
  distance_km: number
}

export interface DriveStats {
  days: number
  journeys: number
  distance_km: number
  duration_sec: number
  avg_speed_kmh: number
  max_speed_kmh: number
  by_day: DayStat[]
  by_vehicle: VehicleStat[]
}

export interface GarageVehicle {
  id: string
  vin?: string
  nickname?: string
  make?: string
  model?: string
  year?: number
  fuel_type?: string
  is_ev: boolean
}

export async function listDrives(limit = 50): Promise<Drive[]> {
  return (await api.get<{ journeys: Drive[] }>(`/journeys?limit=${limit}`)).journeys
}

export function getDriveStats(days: number, tz: string): Promise<DriveStats> {
  return api.get<DriveStats>(`/journeys/stats?days=${days}&tz=${encodeURIComponent(tz)}`)
}

export async function getDriveRoute(id: string, max = 600): Promise<DriveSample[]> {
  return (await api.get<{ samples: DriveSample[] }>(`/journeys/${id}/route?max=${max}`)).samples
}

export async function getDriveSensors(id: string): Promise<Sensor[]> {
  return (await api.get<{ sensors: Sensor[] }>(`/journeys/${id}/sensors`)).sensors
}

export async function getDriveSeries(id: string, pid: string, max = 300): Promise<SeriesPoint[]> {
  return (await api.get<{ points: SeriesPoint[] }>(`/journeys/${id}/series?pid=${encodeURIComponent(pid)}&max=${max}`)).points
}

export async function listGarage(): Promise<GarageVehicle[]> {
  return (await api.get<{ vehicles: GarageVehicle[] }>('/garage/vehicles')).vehicles
}
