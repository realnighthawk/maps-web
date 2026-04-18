import { useEffect } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useApiIsLoaded, useMapsLibrary } from '@vis.gl/react-google-maps'
import { useRoutePlanner } from '../../hooks/useRoutePlanner'
import { useAppStore } from '../../stores/appStore'
import {
  isDefaultOrigin,
  routeEndPlace,
  routeStartPlace,
  useRouteStore,
} from '../../stores/routeStore'
import { resolvePlaceFromDeviceGeolocation } from '../../utils/deviceOriginPlace'

/**
 * One-shot per full page load: if the user opens the route planner without
 * ?from=&to= and the origin is still the default, request GPS and set origin.
 * If a destination is already set, runs planning immediately ("start").
 */
let autodetectLocked = false

export function OriginAutodetect() {
  const mapsApiLoaded = useApiIsLoaded()
  const geocodingLib = useMapsLibrary('geocoding')
  const urlRouteHydrated = useAppStore((s) => s.urlRouteHydrated)
  const activeTab = useAppStore((s) => s.activeTab)
  const [searchParams] = useSearchParams()
  const routeQueryKey = searchParams.toString()
  const setStopPlaceAt = useRouteStore((s) => s.setStopPlaceAt)
  const { runPlan } = useRoutePlanner()

  useEffect(() => {
    if (autodetectLocked) return
    if (!mapsApiLoaded || !geocodingLib || !urlRouteHydrated) return
    if (activeTab !== 'route') return

    const fromQ = searchParams.get('from')?.trim()
    const toQ = searchParams.get('to')?.trim()
    if (fromQ || toQ) {
      autodetectLocked = true
      return
    }

    if (!navigator.geolocation) {
      autodetectLocked = true
      return
    }

    const first = routeStartPlace(useRouteStore.getState().routeStops)
    if (!isDefaultOrigin(first)) {
      autodetectLocked = true
      return
    }

    autodetectLocked = true
    void (async () => {
      try {
        const { place } = await resolvePlaceFromDeviceGeolocation()
        const stillFirst = routeStartPlace(useRouteStore.getState().routeStops)
        if (!isDefaultOrigin(stillFirst)) return
        setStopPlaceAt(0, place)
        const { routeStops, plan, isPlanning } = useRouteStore.getState()
        const dest = routeEndPlace(routeStops)
        if (dest && !plan && !isPlanning) {
          await runPlan()
        }
      } catch {
        /* keep default origin */
      }
    })()
  }, [
    mapsApiLoaded,
    geocodingLib,
    urlRouteHydrated,
    activeTab,
    routeQueryKey,
    setStopPlaceAt,
    runPlan,
  ])

  return null
}
