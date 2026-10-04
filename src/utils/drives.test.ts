import { describe, expect, it } from 'vitest'
import type { GarageVehicle, Sensor } from '../api/journeys'
import { chartGeometry, formatDriveTime, formatMiles, formatMph, formatReading, groupSensors, vehicleName } from './drives'

const s = (pid: string, label = pid): Sensor => ({ pid, label, unit: '', count: 1, min: 0, max: 1, avg: 0.5 })

describe('groupSensors', () => {
  it('sorts everything a drive captured into sections, leaving out empty ones', () => {
    const groups = groupSensors([
      s('phone.baro_kpa', 'Air pressure'), s('gps.alt'), s('gps.lat'), s('7E4.4801'), s('7E4.4800'), s('42'), s('0D'),
    ])
    expect(groups.map((g) => g.title)).toEqual(['Car', 'Module 7E4 (raw values)', 'Location', 'Phone sensors'])
    expect(groups[0].sensors.map((x) => x.pid)).toEqual(['0D', '42'])
    expect(groups[1].sensors.map((x) => x.pid)).toEqual(['7E4.4800', '7E4.4801'])
    expect(groups[2].sensors.map((x) => x.pid)).toEqual(['gps.lat', 'gps.alt'])
    expect(groupSensors([])).toEqual([])
  })

  it('makes one section per module', () => {
    const titles = groupSensors([s('7E4.4801'), s('7E0.1234')]).map((g) => g.title)
    expect(titles).toEqual(['Module 7E0 (raw values)', 'Module 7E4 (raw values)'])
  })
})

describe('formatting', () => {
  it('reads numbers the way the phone apps do', () => {
    expect(formatReading(17410)).toBe('17,410')
    expect(formatReading(13.46)).toBe('13.5')
    expect(formatReading(0.13)).toBe('0.130')
    expect(formatReading(37.123456, 'Latitude')).toBe('37.12346')
    expect(formatReading(NaN)).toBe('—')
  })

  it('shows miles, mph and drive time', () => {
    expect(formatMiles(16.09344)).toBe('10.0 mi')
    expect(formatMiles(573)).toBe('356 mi')
    expect(formatMph(80.4672)).toBe('50 mph')
    expect(formatDriveTime(65 * 60)).toBe('1h 5m')
    expect(formatDriveTime(20)).toBe('20s')
    expect(formatDriveTime(undefined)).toBe('—')
  })

  it('names a car by nickname, then year make model, then id', () => {
    const v: GarageVehicle = { id: 'x', make: 'Ford', model: 'Mustang Mach-E', year: 2023, is_ev: true }
    expect(vehicleName(v, 'x')).toBe('2023 Ford Mustang Mach-E')
    expect(vehicleName({ ...v, nickname: ' Mache ' }, 'x')).toBe('Mache')
    expect(vehicleName(undefined, 'abc')).toBe('abc')
  })
})

describe('chartGeometry', () => {
  it('scales into the box, top is the maximum', () => {
    const g = chartGeometry([0, 10], 100, 50, 0)
    expect(g.line).toBe('M0.0,50.0 L100.0,0.0')
    expect(g.min).toBe(0)
    expect(g.max).toBe(10)
    expect(g.area.endsWith('Z')).toBe(true)
  })

  it('draws a flat series mid-height and copes with one point or none', () => {
    expect(chartGeometry([5, 5, 5], 100, 40, 0).line).toBe('M0.0,20.0 L50.0,20.0 L100.0,20.0')
    expect(chartGeometry([7], 100, 40, 0).line).toBe('M50.0,20.0')
    expect(chartGeometry([], 100, 40).line).toBe('')
  })
})
