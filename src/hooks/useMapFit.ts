import { useEffect, useRef } from 'react'
import { useMap } from '@vis.gl/react-google-maps'
import {
  routeEndPlace,
  routeStartPlace,
  useRouteStore,
} from '../stores/routeStore'
import { decodePolyline } from '../utils/polyline'
import { latLngBounds } from '../utils/geo'

const PADDING = 56

/** Fit map to route polyline when a plan exists. */
export function useMapFitToRoute() {
  const map = useMap()
  const plan = useRouteStore((s) => s.plan)

  useEffect(() => {
    const poly = plan?.route.polyline
    if (!map || !poly) return
    const path = decodePolyline(poly)
    const b = latLngBounds(path)
    if (!b) return
    map.fitBounds(b, PADDING)
  }, [map, plan])
}

/** When there is a plan but no polyline yet, fit all chosen stops. */
export function useMapFitOriginDest() {
  const map = useMap()
  const plan = useRouteStore((s) => s.plan)
  const routeStops = useRouteStore((s) => s.routeStops)

  useEffect(() => {
    if (!map || plan) return
    const start = routeStartPlace(routeStops)
    const end = routeEndPlace(routeStops)
    if (!start || !end) return
    const pts: { lat: number; lng: number }[] = []
    for (const r of routeStops) {
      if (r.place) pts.push({ lat: r.place.lat, lng: r.place.lng })
    }
    if (pts.length < 2) return
    const b = latLngBounds(pts)
    if (!b) return
    map.fitBounds(b, PADDING)
  }, [map, plan, routeStops])
}

/**
 * When there is no route plan and no destination yet, keep the camera on the
 * starting point so the marker stays visible (e.g. after "use my location").
 */
export function useMapPanToSoloOrigin() {
  const map = useMap()
  const plan = useRouteStore((s) => s.plan)
  const routeStops = useRouteStore((s) => s.routeStops)
  const prevOriginKeyRef = useRef<string | null>(null)

  useEffect(() => {
    const start = routeStartPlace(routeStops)
    const end = routeEndPlace(routeStops)
    if (!map || plan || !start || end) return
    const key = `${start.lat},${start.lng}`
    const prevKey = prevOriginKeyRef.current
    const originMoved = prevKey !== null && prevKey !== key
    prevOriginKeyRef.current = key

    map.panTo({ lat: start.lat, lng: start.lng })
    if (originMoved) {
      const z = map.getZoom()
      if (z !== undefined && z < 13) {
        map.setZoom(14)
      }
    }
  }, [map, plan, routeStops])
}
