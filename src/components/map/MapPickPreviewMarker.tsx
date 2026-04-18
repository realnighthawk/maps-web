import {
  AdvancedMarker,
  InfoWindow,
  Pin,
  useAdvancedMarkerRef,
} from '@vis.gl/react-google-maps'
import { useRouteStore } from '../../stores/routeStore'

/** Marker + anchored info window for a map tap until the user adds or dismisses it. */
export function MapPickPreviewMarker() {
  const preview = useRouteStore((s) => s.mapPickPreview)
  const geocoding = useRouteStore((s) => s.mapPickGeocoding)
  const commitMapPickToRoute = useRouteStore((s) => s.commitMapPickToRoute)
  const clearMapPickPreview = useRouteStore((s) => s.clearMapPickPreview)

  const [setMarkerRef, marker] = useAdvancedMarkerRef()

  if (!preview) return null

  return (
    <>
      <AdvancedMarker
        ref={setMarkerRef}
        position={{ lat: preview.lat, lng: preview.lng }}
        title={geocoding ? 'Looking up address…' : preview.name}
      >
        <Pin
          background="#7c3aed"
          borderColor="#ffffff"
          glyphColor="#ffffff"
          glyph={geocoding ? '…' : '?'}
        />
      </AdvancedMarker>

      {marker ? (
        <InfoWindow
          anchor={marker}
          onCloseClick={() => clearMapPickPreview()}
          headerContent={
            <span className="text-sm font-semibold text-slate-900">
              {geocoding ? 'Looking up address…' : 'Map pick'}
            </span>
          }
        >
          <div className="min-w-[220px] max-w-[280px] p-1 font-sans text-slate-800 dark:text-slate-100">
            <p className="text-xs leading-snug text-slate-700 dark:text-slate-200">
              {preview.name}
            </p>
            <p className="mt-1 font-mono text-[10px] text-slate-500 dark:text-slate-400">
              {preview.lat.toFixed(5)}, {preview.lng.toFixed(5)}
            </p>
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                type="button"
                disabled={geocoding}
                onClick={() => commitMapPickToRoute()}
                className="rounded-lg bg-violet-600 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-violet-700 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Add stop
              </button>
              <button
                type="button"
                onClick={() => clearMapPickPreview()}
                className="rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 hover:bg-slate-50 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700"
              >
                Cancel
              </button>
            </div>
          </div>
        </InfoWindow>
      ) : null}
    </>
  )
}
