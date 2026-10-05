import type { Drive } from '../api/journeys'
import type { Trip } from '../api/types'

export type TripFilter = 'all' | 'driven' | 'planned'

/** One entry in the trips list: a route you drove (recorded by the phone) or one you only planned. */
export type TripItem =
  | { kind: 'driven'; at: number; drive: Drive }
  | { kind: 'planned'; at: number; trip: Trip }

/**
 * Driven and planned trips as one list, newest first. A drive and a plan of the same route are not linked on the
 * server, so both appear; when the times tie, the drive comes first.
 */
export function mergeTrips(drives: Drive[], planned: Trip[], filter: TripFilter): TripItem[] {
  const items: TripItem[] = []
  if (filter !== 'planned') {
    for (const drive of drives) items.push({ kind: 'driven', at: Date.parse(drive.started_at), drive })
  }
  if (filter !== 'driven') {
    for (const trip of planned) items.push({ kind: 'planned', at: Date.parse(trip.createdAt), trip })
  }
  return items.sort((a, b) => b.at - a.at || (a.kind === b.kind ? 0 : a.kind === 'driven' ? -1 : 1))
}
