import { useQuery } from '@tanstack/react-query'
import { useEffect } from 'react'
import { getFleetStatus } from '../../api/vehicles'
import { useFleetStore } from '../../stores/fleetStore'

/** Keeps fleet store warm for map markers even before opening the Fleet tab. */
export function FleetQueryBootstrap() {
  const setVehicles = useFleetStore((s) => s.setVehicles)
  const { data } = useQuery({
    queryKey: ['fleet'],
    queryFn: getFleetStatus,
    refetchInterval: 30_000,
  })

  useEffect(() => {
    if (data) setVehicles(data)
  }, [data, setVehicles])

  return null
}
