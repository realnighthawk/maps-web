import { useEffect } from 'react'
import { MapView } from './components/map/MapView'
import { SearchPanel } from './components/search/SearchPanel'
import { TripPanel } from './components/trip/TripPanel'
import { FleetQueryBootstrap } from './components/fleet/FleetQueryBootstrap'
import { FleetView } from './components/fleet/FleetView'
import { VehicleDetailSheet } from './components/fleet/VehicleDetailSheet'
import { TripsView } from './components/trips/TripsView'
import { SettingsView } from './components/settings/SettingsView'
import { BottomNav } from './components/shared/BottomNav'
import { ErrorBanner } from './components/shared/ErrorBanner'
import { LoadingOverlay } from './components/shared/LoadingOverlay'
import { OriginAutodetect } from './components/shell/OriginAutodetect'
import {
  DocumentTitle,
  RouteUrlSync,
  RouteUrlWriter,
} from './components/shell/RouteSync'
import { useDarkClassSync } from './hooks/useTheme'
import { useFleetWebSocket } from './hooks/useWebSocket'
import { useAppStore } from './stores/appStore'
import { useFleetStore } from './stores/fleetStore'
import { useRouteStore } from './stores/routeStore'

export default function App() {
  useDarkClassSync()
  useFleetWebSocket(true)

  const activeTab = useAppStore((s) => s.activeTab)
  const plan = useRouteStore((s) => s.plan)
  const fleetDetailVin = useFleetStore((s) => s.fleetDetailVin)
  const setFleetDetailVin = useFleetStore((s) => s.setFleetDetailVin)

  useEffect(() => {
    if (activeTab !== 'fleet') setFleetDetailVin(null)
  }, [activeTab, setFleetDetailVin])

  useEffect(() => {
    if (activeTab !== 'route') {
      useRouteStore.getState().clearMapPickPreview()
    }
  }, [activeTab])

  return (
    <div className="relative h-screen w-screen bg-slate-100 dark:bg-slate-950">
      <MapView
        overlay={
          <>
            <FleetQueryBootstrap />
            <LoadingOverlay />
            <RouteUrlSync />
            <OriginAutodetect />
            <RouteUrlWriter />
            <DocumentTitle />
            <div className="pointer-events-none absolute inset-0 flex flex-col gap-4 overflow-y-auto p-4 xl:flex-row xl:justify-between xl:overflow-hidden">
              <div className="pointer-events-none flex min-w-0 flex-col gap-3 xl:max-w-[min(100%,28rem)]">
                {activeTab === 'route' && (
                  <>
                    <SearchPanel />
                    <ErrorBanner />
                  </>
                )}
                {activeTab === 'fleet' && <FleetView />}
                {activeTab === 'trips' && <TripsView />}
                {activeTab === 'settings' && <SettingsView />}
              </div>
              {activeTab === 'route' && plan && (
                <div className="pointer-events-auto w-full max-w-md shrink-0 xl:ml-auto xl:mt-0">
                  <TripPanel />
                </div>
              )}
            </div>
            {activeTab === 'fleet' && fleetDetailVin && (
              <VehicleDetailSheet
                vin={fleetDetailVin}
                onClose={() => setFleetDetailVin(null)}
              />
            )}
            <div className="pointer-events-none absolute bottom-4 left-0 right-0 flex justify-center px-4">
              <BottomNav />
            </div>
          </>
        }
      />
    </div>
  )
}
