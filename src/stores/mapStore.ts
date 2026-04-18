import { create } from 'zustand'

interface MapState {
  mapInstance: google.maps.Map | null
  setMapInstance: (map: google.maps.Map | null) => void
  panTo: (lat: number, lng: number, zoom?: number) => void
}

export const useMapStore = create<MapState>((set, get) => ({
  mapInstance: null,
  setMapInstance: (map) => set({ mapInstance: map }),
  panTo: (lat, lng, zoom) => {
    const map = get().mapInstance
    if (!map) return
    map.panTo({ lat, lng })
    if (zoom !== undefined) map.setZoom(zoom)
  },
}))
