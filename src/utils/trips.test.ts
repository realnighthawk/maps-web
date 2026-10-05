import { describe, expect, it } from 'vitest'
import type { Drive } from '../api/journeys'
import type { Trip } from '../api/types'
import { ApiError } from '../api/client'
import { describeError } from './errors'
import { mergeTrips } from './trips'

const drive = (id: string, at: string): Drive => ({
  id, vehicle_id: 'car', status: 'COMPLETED', started_at: at, observations: 1, distance_km: 1, avg_speed_kmh: 1, max_speed_kmh: 1,
})
const trip = (id: string, at: string): Trip => ({
  id, createdAt: at, origin: { lat: 0, lng: 0 }, destination: { lat: 1, lng: 1 },
  totalDistanceMeters: 1, totalDurationSeconds: 1, totalCostDollars: 0,
})

describe('mergeTrips', () => {
  const drives = [drive('d1', '2026-10-03T10:00:00Z'), drive('d2', '2026-10-01T10:00:00Z')]
  const plans = [trip('p1', '2026-10-02T10:00:00Z'), trip('p2', '2026-10-03T10:00:00Z')]

  it('puts driven and planned trips in one list, newest first', () => {
    const ids = mergeTrips(drives, plans, 'all').map((i) => (i.kind === 'driven' ? i.drive.id : i.trip.id))
    // d1 and p2 share a time: the drive comes first.
    expect(ids).toEqual(['d1', 'p2', 'p1', 'd2'])
  })

  it('filters to one kind', () => {
    expect(mergeTrips(drives, plans, 'driven').every((i) => i.kind === 'driven')).toBe(true)
    expect(mergeTrips(drives, plans, 'planned').map((i) => i.kind)).toEqual(['planned', 'planned'])
    expect(mergeTrips([], [], 'all')).toEqual([])
  })
})

describe('describeError', () => {
  it('explains the router answering for a missing or expired account', () => {
    expect(describeError(new ApiError(404, 'no_tenant', 'no_tenant'), 'trips')).toMatch(/isn't set up/)
    expect(describeError(new ApiError(401, 'x'), 'trips')).toMatch(/sign in again/)
    expect(describeError(new ApiError(500, 'boom'), 'trips')).toBe('Could not load your trips.')
    expect(describeError(new Error('network'), 'drives')).toBe('Could not load your drives.')
  })
})
