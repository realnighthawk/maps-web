import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { getUserMe, setActiveVehicleVin } from '../../api/fleet'
import {
  getFleetStatus,
  initialVehicleStateAfterOnboard,
  onboardVehicleFromVin,
  putVehicleState,
} from '../../api/vehicles'
import { ApiError } from '../../api/client'
import { useFleetStore } from '../../stores/fleetStore'
import { VehicleCard } from './VehicleCard'

export function FleetView() {
  const queryClient = useQueryClient()
  const setVehicles = useFleetStore((s) => s.setVehicles)
  const setFleetDetailVin = useFleetStore((s) => s.setFleetDetailVin)
  const vehicles = useFleetStore((s) => s.vehicles)
  const [vinInput, setVinInput] = useState('')

  const { data, isLoading, isError } = useQuery({
    queryKey: ['fleet'],
    queryFn: getFleetStatus,
    refetchInterval: 30_000,
  })

  const { data: userMe, isSuccess: userMeReady } = useQuery({
    queryKey: ['user', 'me'],
    queryFn: getUserMe,
    retry: 1,
    staleTime: 60_000,
  })

  const setActiveVehicle = useMutation({
    mutationFn: (vin: string) => setActiveVehicleVin(vin),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['user', 'me'] })
    },
  })

  useEffect(() => {
    if (data) setVehicles(data)
  }, [data, setVehicles])

  const onboard = useMutation({
    mutationFn: async () => {
      const v = vinInput.trim().toUpperCase()
      if (v.length < 11) {
        throw new Error('Enter a valid VIN (at least 11 characters).')
      }
      const result = await onboardVehicleFromVin(v)
      return { vin: v, result }
    },
    onSuccess: async ({ vin, result }) => {
      setVinInput('')
      try {
        await putVehicleState(vin, initialVehicleStateAfterOnboard(result.profile))
      } catch (e) {
        console.warn('Could not seed vehicle state', e)
      }
      await queryClient.invalidateQueries({ queryKey: ['fleet'] })
      await queryClient.invalidateQueries({ queryKey: ['vehicle', vin] })
      if (result.warnings?.length) {
        console.warn('Vehicle onboard warnings', result.warnings)
      }
    },
  })

  return (
    <div className="pointer-events-auto w-full max-w-sm rounded-2xl border border-slate-200/80 bg-white/95 p-4 shadow-xl backdrop-blur-sm dark:border-slate-700/80 dark:bg-slate-900/95">
      <h2 className="text-lg font-semibold text-slate-900 dark:text-slate-100">
        Fleet
      </h2>
      <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
        Onboard with your VIN (NHTSA + EPA index). Refreshes every 30s. Live
        updates when WebSocket is connected. Set the{' '}
        <span className="font-medium text-slate-600 dark:text-slate-300">
          active
        </span>{' '}
        vehicle for route planning (saved when the API database is enabled).
      </p>

      <form
        className="mt-4 space-y-2 rounded-xl border border-slate-200 bg-slate-50/80 p-3 dark:border-slate-600 dark:bg-slate-800/50"
        onSubmit={(e) => {
          e.preventDefault()
          onboard.mutate()
        }}
      >
        <label className="block text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          Add vehicle by VIN
        </label>
        <input
          type="text"
          value={vinInput}
          onChange={(e) => setVinInput(e.target.value.toUpperCase())}
          placeholder="e.g. 5YJ3E1EA1JF000000"
          autoComplete="off"
          className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 font-mono text-sm uppercase tracking-wide dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
        />
        <button
          type="submit"
          disabled={onboard.isPending}
          className="w-full rounded-lg bg-slate-900 py-2 text-sm font-semibold text-white hover:bg-slate-800 disabled:opacity-50 dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-white"
        >
          {onboard.isPending ? 'Onboarding…' : 'Onboard vehicle'}
        </button>
        {onboard.isError && (
          <p className="text-xs text-red-600 dark:text-red-400">
            {onboard.error instanceof ApiError
              ? onboard.error.message
              : onboard.error instanceof Error
                ? onboard.error.message
                : 'Onboarding failed'}
          </p>
        )}
        {onboard.isSuccess &&
          (onboard.data?.result.warnings?.length ?? 0) > 0 && (
            <ul className="list-inside list-disc text-xs text-amber-700 dark:text-amber-400">
              {(onboard.data?.result.warnings ?? []).map((w) => (
                <li key={w}>{w}</li>
              ))}
            </ul>
          )}
      </form>
      {isLoading && vehicles.length === 0 && (
        <p className="mt-4 text-sm text-slate-500">Loading fleet…</p>
      )}
      {isError && (
        <p className="mt-4 text-sm text-red-600 dark:text-red-400">
          Could not load fleet status.
        </p>
      )}
      {setActiveVehicle.isError && (
        <p className="mt-3 text-xs text-red-600 dark:text-red-400">
          Could not save active vehicle. Is maps-engine running with Postgres?
        </p>
      )}
      <ul className="mt-3 space-y-2">
        {vehicles.map((v) => (
          <li key={v.vin}>
            <VehicleCard
              vehicle={v}
              activeVin={userMe?.active_vehicle_vin}
              onSetActive={
                userMeReady
                  ? () => setActiveVehicle.mutate(v.vin)
                  : undefined
              }
              setActiveLoading={
                setActiveVehicle.isPending &&
                setActiveVehicle.variables === v.vin
              }
              onSelect={() => setFleetDetailVin(v.vin)}
            />
          </li>
        ))}
      </ul>

      {!isLoading && !isError && vehicles.length === 0 && (
        <p className="mt-4 text-sm text-slate-500">No vehicles in fleet.</p>
      )}
    </div>
  )
}
