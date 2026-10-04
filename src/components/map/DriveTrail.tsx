import { AdvancedMarker, Polyline, useMap } from '@vis.gl/react-google-maps'
import { useEffect, useMemo } from 'react'
import { useDriveRoute } from '../../hooks/useDrives'
import { useDriveStore } from '../../stores/driveStore'
import { latLngBounds } from '../../utils/geo'

/**
 * Room to leave when fitting the trail: the side panel covers the left on a wide screen (it is about 28rem plus its
 * margin), and the tab bar covers the bottom.
 */
function fitPadding(): google.maps.Padding {
  const wide = window.innerWidth >= 1280
  return { top: 72, right: 72, bottom: 104, left: wide ? 480 : 72 }
}

/** The open drive's path on the map, with its start and end, fitted into view. Points with no GPS fix are skipped. */
export function DriveTrail() {
  const map = useMap()
  const id = useDriveStore((s) => s.selectedId)
  const { data } = useDriveRoute(id)

  const path = useMemo(
    () =>
      (data ?? [])
        .filter((p) => p.lat !== undefined && p.lng !== undefined)
        .map((p) => ({ lat: p.lat as number, lng: p.lng as number })),
    [data],
  )

  useEffect(() => {
    const b = latLngBounds(path)
    if (map && b) map.fitBounds(b, fitPadding())
  }, [map, path])

  if (!id || path.length < 2) return null
  const dot = (color: string, label: string) => (
    <div className={`h-3.5 w-3.5 rounded-full ring-2 ring-white ${color}`} role="img" aria-label={label} />
  )
  return (
    <>
      <Polyline path={path} strokeColor="#bfdbfe" strokeOpacity={0.85} strokeWeight={10} />
      <Polyline path={path} strokeColor="#2563eb" strokeOpacity={0.95} strokeWeight={5} />
      <AdvancedMarker position={path[0]} title="Start">{dot('bg-emerald-500', 'Start of the drive')}</AdvancedMarker>
      <AdvancedMarker position={path[path.length - 1]} title="End">{dot('bg-rose-500', 'End of the drive')}</AdvancedMarker>
    </>
  )
}
