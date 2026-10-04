import type { GarageVehicle, Sensor } from '../api/journeys'

const KM_PER_MILE = 1.609344

export function kmToMiles(km: number): number {
  return km / KM_PER_MILE
}

/** "12.4 mi" under 100 miles, "356 mi" above. */
export function formatMiles(km: number): string {
  if (!Number.isFinite(km) || km < 0) return '—'
  const mi = kmToMiles(km)
  return `${mi < 100 ? mi.toFixed(1) : Math.round(mi)} mi`
}

export function formatMph(kmh: number): string {
  if (!Number.isFinite(kmh) || kmh < 0) return '—'
  return `${Math.round(kmToMiles(kmh))} mph`
}

/** "1h 5m", "14m", "45s". */
export function formatDriveTime(seconds: number | undefined): string {
  if (seconds === undefined || !Number.isFinite(seconds) || seconds < 0) return '—'
  if (seconds < 60) return `${Math.round(seconds)}s`
  const h = Math.floor(seconds / 3600)
  const m = Math.round((seconds % 3600) / 60)
  if (h === 0) return `${m}m`
  return m === 0 ? `${h}h` : `${h}h ${m}m`
}

/** What to call a car: its nickname, else "2023 Ford Mustang Mach-E", else the id. */
export function vehicleName(v: GarageVehicle | undefined, fallbackId: string): string {
  if (!v) return fallbackId
  if (v.nickname?.trim()) return v.nickname.trim()
  const s = [v.year, v.make, v.model].filter(Boolean).join(' ')
  return s || fallbackId
}

/**
 * A number as it reads best: whole numbers plain, small ones with the decimals that matter, large ones without.
 * Same rules as the phone apps' Live screen, so the same reading looks the same everywhere.
 */
export function formatReading(value: number, label = ''): string {
  if (!Number.isFinite(value)) return '—'
  if (label === 'Latitude' || label === 'Longitude') return value.toFixed(5)
  if (Number.isInteger(value) || Math.abs(value) >= 1000) return Math.round(value).toLocaleString('en-US')
  if (Math.abs(value) < 1) return value.toFixed(3)
  return value.toFixed(1)
}

export interface SensorGroup {
  title: string
  sensors: Sensor[]
}

const GPS_ORDER = ['gps.lat', 'gps.lng', 'gps.acc', 'gps.alt', 'gps.course', 'gps.speed']
const MODULE = /^[0-9A-F]{3}\./

/**
 * Everything a drive captured, in sections: the car's standard readings, readings specific to its model (one section
 * per module), the GPS fix, and the phone's own sensors. Empty sections are left out.
 */
export function groupSensors(sensors: Sensor[]): SensorGroup[] {
  const byPid = (a: Sensor, b: Sensor) => a.pid.localeCompare(b.pid)
  const car = sensors.filter((s) => !s.pid.includes('.')).sort(byPid)
  const modules = [...new Set(sensors.filter((s) => MODULE.test(s.pid)).map((s) => s.pid.slice(0, 3)))].sort()
  const gps = sensors
    .filter((s) => s.pid.startsWith('gps.'))
    .sort((a, b) => (GPS_ORDER.indexOf(a.pid) + 1 || 99) - (GPS_ORDER.indexOf(b.pid) + 1 || 99))
  const phone = sensors.filter((s) => s.pid.startsWith('phone.')).sort((a, b) => a.label.localeCompare(b.label))

  const groups: SensorGroup[] = [
    { title: 'Car', sensors: car },
    ...modules.map((m) => ({
      title: `Module ${m} (raw values)`,
      sensors: sensors.filter((s) => s.pid.startsWith(`${m}.`)).sort(byPid),
    })),
    { title: 'Location', sensors: gps },
    { title: 'Phone sensors', sensors: phone },
  ]
  return groups.filter((g) => g.sensors.length > 0)
}

export interface ChartGeometry {
  /** SVG path for the line, or '' when there is nothing to draw. */
  line: string
  /** The same line closed down to the baseline, for the soft fill. */
  area: string
  min: number
  max: number
}

/**
 * Scales values into a width x height box (padded), time-ordered and evenly spaced. A flat series draws mid-height
 * rather than dividing by zero.
 */
export function chartGeometry(values: number[], width: number, height: number, pad = 4): ChartGeometry {
  if (values.length === 0) return { line: '', area: '', min: 0, max: 0 }
  const min = Math.min(...values)
  const max = Math.max(...values)
  const span = max - min
  const x = (i: number) => pad + (values.length === 1 ? (width - 2 * pad) / 2 : (i * (width - 2 * pad)) / (values.length - 1))
  const y = (v: number) => (span === 0 ? height / 2 : pad + (1 - (v - min) / span) * (height - 2 * pad))
  const pts = values.map((v, i) => `${x(i).toFixed(1)},${y(v).toFixed(1)}`)
  const line = `M${pts.join(' L')}`
  const area = `${line} L${x(values.length - 1).toFixed(1)},${height - pad} L${x(0).toFixed(1)},${height - pad} Z`
  return { line, area, min, max }
}
