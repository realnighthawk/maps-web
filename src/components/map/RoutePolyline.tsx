import { useEffect, useMemo, useState } from 'react'
import { Polyline } from '@vis.gl/react-google-maps'
import { useRouteStore } from '../../stores/routeStore'
import { decodePolyline } from '../../utils/polyline'

export function RoutePolyline() {
  const plan = useRouteStore((s) => s.plan)
  const encoded = plan?.route.polyline ?? ''
  const fullPath = useMemo(
    () => (encoded ? decodePolyline(encoded) : []),
    [encoded],
  )
  const [visibleLen, setVisibleLen] = useState(0)

  useEffect(() => {
    if (fullPath.length === 0) {
      setVisibleLen(0)
      return
    }
    setVisibleLen(0)
    const step = Math.max(1, Math.ceil(fullPath.length / 24))
    let i = 0
    const id = window.setInterval(() => {
      i = Math.min(i + step, fullPath.length)
      setVisibleLen(i)
      if (i >= fullPath.length) window.clearInterval(id)
    }, 20)
    return () => window.clearInterval(id)
  }, [fullPath])

  if (!plan || fullPath.length === 0) return null

  const path = fullPath.slice(0, Math.max(visibleLen, 2))

  return (
    <>
      <Polyline
        path={path}
        strokeColor="#bfdbfe"
        strokeOpacity={0.85}
        strokeWeight={10}
        geodesic
      />
      <Polyline
        path={path}
        strokeColor="#2563eb"
        strokeOpacity={0.92}
        strokeWeight={5}
        geodesic
      />
    </>
  )
}
