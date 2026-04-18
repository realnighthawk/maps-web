import type { RoutePlanResponse } from '../api/contract/routePlan'

export interface StopTimelineTimes {
  originDepart: Date
  stops: { arrive: Date; depart: Date }[]
  destArrive: Date
}

/**
 * Approximate schedule from segment drive times + stop durations.
 * Uses each planned stop's segmentIndex (where it sits along the route), not list order.
 */
export function computeTimelineTimes(plan: RoutePlanResponse): StopTimelineTimes {
  const segs = plan.route.segments
  let t = Date.now()
  const originDepart = new Date(t)

  if (plan.stops.length === 0) {
    for (const seg of segs) {
      t += seg.durationSec * 1000
    }
    return { originDepart, stops: [], destArrive: new Date(t) }
  }

  const ordered = plan.stops.map((stop, i) => ({ stop, i }))
  ordered.sort((a, b) => {
    if (a.stop.segmentIndex !== b.stop.segmentIndex) {
      return a.stop.segmentIndex - b.stop.segmentIndex
    }
    return a.i - b.i
  })

  const timesByOriginalIndex: { arrive: Date; depart: Date }[] = new Array(
    plan.stops.length,
  )
  let segCursor = 0

  for (const { stop, i } of ordered) {
    const lastSegBeforeStop = Math.min(
      Math.max(0, stop.segmentIndex),
      Math.max(0, segs.length - 1),
    )
    while (segCursor <= lastSegBeforeStop && segCursor < segs.length) {
      t += (segs[segCursor]?.durationSec ?? 0) * 1000
      segCursor++
    }
    const arrive = new Date(t)
    t += (stop.stopDurationMin ?? 0) * 60 * 1000
    timesByOriginalIndex[i] = { arrive, depart: new Date(t) }
  }

  while (segCursor < segs.length) {
    t += (segs[segCursor]?.durationSec ?? 0) * 1000
    segCursor++
  }

  return {
    originDepart,
    stops: timesByOriginalIndex,
    destArrive: new Date(t),
  }
}
