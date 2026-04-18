import { useMap } from '@vis.gl/react-google-maps'
import { useCallback, useEffect, useRef } from 'react'
import { useRouteStore } from '../../stores/routeStore'
import { pickBestReverseGeocodeResult } from '../../utils/reverseGeocode'
import { reverseGeocodeLatLng } from '../../utils/reverseGeocodeRequest'

function placeLabelFromLatLng(lat: number, lng: number): string {
  return `${lat.toFixed(5)}, ${lng.toFixed(5)}`
}

/**
 * On the route tab, a map click stages a pick (reverse-geocoded). The user adds
 * it to the route with "Add stop" in the panel.
 */
export function MapRouteClickHandler() {
  const map = useMap()
  const setMapPickPreview = useRouteStore((s) => s.setMapPickPreview)
  const setMapPickGeocoding = useRouteStore((s) => s.setMapPickGeocoding)
  const geocodeSeq = useRef(0)

  const onMapClick = useCallback(
    async (e: google.maps.MapMouseEvent) => {
      // Avoid Google’s default POI / place panel (e.g. “View on Google Maps”).
      e.stop()
      const latLng = e.latLng
      if (!latLng) return
      const lat = latLng.lat()
      const lng = latLng.lng()
      const coordLabel = placeLabelFromLatLng(lat, lng)
      const seq = ++geocodeSeq.current

      setMapPickPreview({ name: coordLabel, lat, lng })
      setMapPickGeocoding(true)

      let name = coordLabel
      try {
        const { results, status } = await reverseGeocodeLatLng(lat, lng)
        if (seq !== geocodeSeq.current) return
        if (status === 'OK' && results.length) {
          const r = pickBestReverseGeocodeResult(results, lat, lng)
          if (r?.formatted_address) name = r.formatted_address
        }
      } catch {
        /* keep coordinate label */
      } finally {
        if (seq !== geocodeSeq.current) return
        setMapPickPreview({ name, lat, lng })
        setMapPickGeocoding(false)
      }
    },
    [setMapPickGeocoding, setMapPickPreview],
  )

  useEffect(() => {
    if (!map) return
    const listener = map.addListener('click', onMapClick)
    return () => {
      listener.remove()
    }
  }, [map, onMapClick])

  return null
}
