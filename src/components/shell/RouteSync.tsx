import { useApiIsLoaded } from '@vis.gl/react-google-maps'
import { useEffect, useMemo, useRef } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useRoutePlanner } from '../../hooks/useRoutePlanner'
import { useAppStore } from '../../stores/appStore'
import {
  newRouteStopRow,
  routeEndPlace,
  routeStartPlace,
  useRouteStore,
} from '../../stores/routeStore'
import type { Place } from '../../stores/routeStore'

function geocodeOne(
  gc: google.maps.Geocoder,
  address: string,
): Promise<google.maps.GeocoderResult | null> {
  return new Promise((resolve) => {
    gc.geocode({ address }, (results, status) => {
      if (status !== 'OK' || !results?.[0]?.geometry?.location) {
        resolve(null)
        return
      }
      resolve(results[0]!)
    })
  })
}

/** Geocode `?from=&to=` and optional repeated `via=`; auto-plan once the Maps API is ready. */
export function RouteUrlSync() {
  const loaded = useApiIsLoaded()
  const [searchParams] = useSearchParams()
  const fromQ = searchParams.get('from')
  const toQ = searchParams.get('to')
  const querySignature = searchParams.toString()
  const viaQueries = useMemo(
    () => [...searchParams.getAll('via')],
    [querySignature],
  )
  const setUrlRouteHydrated = useAppStore((s) => s.setUrlRouteHydrated)
  const setRouteStops = useRouteStore((s) => s.setRouteStops)
  const { runPlan } = useRoutePlanner()
  const runPlanRef = useRef(runPlan)
  runPlanRef.current = runPlan

  useEffect(() => {
    const from = fromQ
    const to = toQ
    if (!from || !to) {
      setUrlRouteHydrated(true)
      return
    }

    if (!loaded) return

    const routeStops = useRouteStore.getState().routeStops
    const start = routeStartPlace(routeStops)
    const end = routeEndPlace(routeStops)
    const midNames = routeStops
      .slice(1, -1)
      .map((r) => r.place?.name)
      .filter((n): n is string => Boolean(n))
    const alreadySynced =
      start != null &&
      end != null &&
      start.name === from &&
      end.name === to &&
      viaQueries.length === midNames.length &&
      viaQueries.every((q, i) => q === midNames[i])
    if (alreadySynced) {
      setUrlRouteHydrated(true)
      return
    }

    let cancelled = false
    const gc = new google.maps.Geocoder()

    void (async () => {
      const fromRes = await geocodeOne(gc, from)
      if (cancelled) return
      if (!fromRes?.geometry?.location) {
        setUrlRouteHydrated(true)
        return
      }
      const ol = fromRes.geometry.location
      const startPlace: Place = {
        name: fromRes.formatted_address ?? from,
        lat: ol.lat(),
        lng: ol.lng(),
      }

      const viaPlaces: Place[] = []
      for (const vq of viaQueries) {
        const vr = await geocodeOne(gc, vq)
        if (cancelled) return
        if (vr?.geometry?.location) {
          const l = vr.geometry.location
          viaPlaces.push({
            name: vr.formatted_address ?? vq,
            lat: l.lat(),
            lng: l.lng(),
          })
        }
      }

      const toRes = await geocodeOne(gc, to)
      if (cancelled) return
      if (!toRes?.geometry?.location) {
        setUrlRouteHydrated(true)
        return
      }
      const dl = toRes.geometry.location
      const endPlace: Place = {
        name: toRes.formatted_address ?? to,
        lat: dl.lat(),
        lng: dl.lng(),
      }

      setRouteStops([
        newRouteStopRow(startPlace),
        ...viaPlaces.map((p) => newRouteStopRow(p)),
        newRouteStopRow(endPlace),
      ])
      setUrlRouteHydrated(true)
      queueMicrotask(() => void runPlanRef.current())
    })()

    return () => {
      cancelled = true
    }
  }, [
    loaded,
    fromQ,
    toQ,
    viaQueries,
    setRouteStops,
    setUrlRouteHydrated,
  ])

  return null
}

/** Keep shareable query params in sync with the route store. */
export function RouteUrlWriter() {
  const hydrated = useAppStore((s) => s.urlRouteHydrated)
  const [searchParams, setSearchParams] = useSearchParams()
  const routeStops = useRouteStore((s) => s.routeStops)
  const querySnapshot = searchParams.toString()

  useEffect(() => {
    if (!hydrated) return
    const start = routeStartPlace(routeStops)
    const end = routeEndPlace(routeStops)
    if (!start || !end) {
      if (querySnapshot !== '') {
        setSearchParams({}, { replace: true })
      }
      return
    }
    const params = new URLSearchParams()
    params.set('from', start.name)
    params.set('to', end.name)
    for (const row of routeStops.slice(1, -1)) {
      if (row.place) params.append('via', row.place.name)
    }
    const next = params.toString()
    if (next === querySnapshot) return
    setSearchParams(params, { replace: true })
  }, [hydrated, routeStops, querySnapshot, setSearchParams])

  return null
}

export function DocumentTitle() {
  const routeStops = useRouteStore((s) => s.routeStops)
  const plan = useRouteStore((s) => s.plan)

  useEffect(() => {
    const names = routeStops
      .map((r) => r.place?.name)
      .filter((n): n is string => Boolean(n))
    if (plan && names.length >= 2) {
      document.title = `${names.join(' → ')} — Fleet Router`
    } else {
      document.title = 'Fleet Router'
    }
  }, [plan, routeStops])

  return null
}
