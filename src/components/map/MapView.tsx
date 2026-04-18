import { APIProvider, ControlPosition, Map } from '@vis.gl/react-google-maps'
import type { ReactNode } from 'react'
import { useAppStore } from '../../stores/appStore'
import { useRouteStore } from '../../stores/routeStore'
import { useResolvedDark } from '../../hooks/useTheme'
import { resolvedMapColorScheme } from '../../utils/mapStyles'
import { MapBindings } from './MapBindings'
import { MapPickPreviewMarker } from './MapPickPreviewMarker'
import { MapRouteClickHandler } from './MapRouteClickHandler'
import { RoutePolyline } from './RoutePolyline'
import { RouteStopsMarkers } from './RouteStopsMarkers'
import { ChargerMarker } from './ChargerMarker'
import { FleetVehicleMarkers } from './FleetVehicleMarkers'

const SAN_JOSE: google.maps.LatLngLiteral = { lat: 37.3382, lng: -121.8863 }

/** Advanced markers require a map ID; DEMO_MAP_ID works for local/testing per Google samples. */
const MAP_ID =
  import.meta.env.VITE_GOOGLE_MAPS_MAP_ID?.trim() || 'DEMO_MAP_ID'

interface MapViewProps {
  /** Floating UI rendered inside APIProvider (e.g. search uses Places library). */
  overlay?: ReactNode
}

export function MapView({ overlay }: MapViewProps) {
  const apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY
  const activeTab = useAppStore((s) => s.activeTab)
  const plan = useRouteStore((s) => s.plan)
  const selectedStopIndex = useRouteStore((s) => s.selectedStopIndex)
  const setSelectedStopIndex = useRouteStore((s) => s.setSelectedStopIndex)
  const isDark = useResolvedDark()

  return (
    <APIProvider apiKey={apiKey} libraries={['places', 'marker', 'geocoding']}>
      <div className="relative h-full w-full">
        <Map
          className="absolute inset-0 h-full w-full"
          mapId={MAP_ID}
          defaultCenter={SAN_JOSE}
          defaultZoom={10}
          /** Route tab: let map clicks hit our handler instead of Google’s POI card. */
          clickableIcons={activeTab !== 'route'}
          gestureHandling="greedy"
          disableDefaultUI={false}
          zoomControl
          zoomControlOptions={{ position: ControlPosition.RIGHT_BOTTOM }}
          mapTypeControl={false}
          streetViewControl={false}
          fullscreenControl={false}
          colorScheme={resolvedMapColorScheme(isDark)}
        >
          <MapBindings />
          {activeTab === 'route' ? <MapRouteClickHandler /> : null}
          <RoutePolyline />
          {activeTab === 'fleet' ? (
            <FleetVehicleMarkers />
          ) : (
            <>
              <MapPickPreviewMarker />
              <RouteStopsMarkers />
              {plan?.stops.map((stop, index) => (
                <ChargerMarker
                  key={`${stop.name}-${stop.segmentIndex}-${index}`}
                  stop={stop}
                  index={index}
                  selected={selectedStopIndex === index}
                  onSelect={() => setSelectedStopIndex(index)}
                />
              ))}
            </>
          )}
        </Map>
        {overlay}
      </div>
    </APIProvider>
  )
}
