import { useEffect } from 'react'
import { useMap } from '@vis.gl/react-google-maps'
import { useMapStore } from '../../stores/mapStore'
import {
  useMapFitOriginDest,
  useMapFitToRoute,
  useMapPanToSoloOrigin,
} from '../../hooks/useMapFit'

export function MapBindings() {
  const map = useMap()
  const setMapInstance = useMapStore((s) => s.setMapInstance)

  useEffect(() => {
    if (map) setMapInstance(map)
    return () => setMapInstance(null)
  }, [map, setMapInstance])

  useMapFitToRoute()
  useMapFitOriginDest()
  useMapPanToSoloOrigin()

  return null
}
