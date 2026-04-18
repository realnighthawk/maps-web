import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import {
  updateVehicleProfile,
  VEHICLE_CONNECTOR_TYPE_VALUES,
} from '../../api/vehicles'
import type {
  VehicleDetailResponse,
  VehicleProfileWire,
} from '../../api/vehicleProfile'

function connectorOptionLabel(value: string): string {
  switch (value) {
    case 'TESLA':
      return 'Tesla (NACS / proprietary)'
    case 'J1772':
      return 'J1772 (Type 1 AC)'
    case 'CHAdeMO':
      return 'CHAdeMO'
    case 'CCS':
      return 'CCS (Combo)'
    default:
      return value
  }
}

const DETAIL_QUERY_KEY = (vin: string) => ['vehicle', vin, 'detail'] as const

/**
 * Inline add/remove for `connector_types` with immediate PUT to the fleet API.
 */
export function VehicleConnectorsEditor({
  vin,
  profile,
}: {
  vin: string
  profile: VehicleProfileWire
}) {
  const queryClient = useQueryClient()
  const [pick, setPick] = useState('')

  const list = profile.connector_types ?? []

  const saveMutation = useMutation({
    mutationFn: async (nextTypes: string[]) => {
      if (nextTypes.length < 1) {
        throw new Error(
          'At least one connector type is required for electric vehicles.',
        )
      }
      const cached = queryClient.getQueryData<VehicleDetailResponse>(
        DETAIL_QUERY_KEY(vin),
      )
      const prof =
        cached?.profile?.vin === vin ? cached.profile : profile
      if (!prof || prof.vin !== vin) {
        throw new Error('Vehicle profile not loaded')
      }
      return updateVehicleProfile(vin, {
        ...prof,
        connector_types: nextTypes,
      })
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: DETAIL_QUERY_KEY(vin) })
      void queryClient.invalidateQueries({ queryKey: ['vehicle', vin] })
    },
  })

  const have = new Set(list.map((t) => t.toUpperCase()))
  const available = VEHICLE_CONNECTOR_TYPE_VALUES.filter(
    (c) => !have.has(c.toUpperCase()),
  )

  const busy = saveMutation.isPending

  return (
    <div className="space-y-2">
      {list.length === 0 ? (
        <p className="text-sm text-slate-500 dark:text-slate-400">
          Add at least one connector type — it is required for charger search and
          route planning.
        </p>
      ) : (
        <ul className="flex flex-col gap-1.5" aria-label="Connector types">
          {list.map((c, i) => (
            <li
              key={`${c}-${i}`}
              className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-slate-200 bg-white px-2.5 py-1.5 dark:border-slate-600 dark:bg-slate-900"
            >
              <span className="text-sm font-medium text-slate-800 dark:text-slate-100">
                {connectorOptionLabel(c)}
              </span>
              <button
                type="button"
                disabled={busy || list.length <= 1}
                title={
                  list.length <= 1
                    ? 'At least one connector must remain'
                    : undefined
                }
                className="shrink-0 rounded-md px-2 py-1 text-xs font-semibold text-red-600 transition enabled:hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-40 dark:text-red-400 dark:enabled:hover:bg-red-950/40"
                onClick={() => {
                  if (list.length <= 1) return
                  const next = list.filter((_, idx) => idx !== i)
                  saveMutation.mutate(next)
                }}
              >
                Remove
              </button>
            </li>
          ))}
        </ul>
      )}

      <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center">
        <label className="sr-only" htmlFor={`connector-pick-${vin}`}>
          Add connector type
        </label>
        <select
          id={`connector-pick-${vin}`}
          className="min-w-0 flex-1 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100 sm:max-w-[240px]"
          value={pick}
          disabled={busy || available.length === 0}
          onChange={(e) => setPick(e.target.value)}
        >
          <option value="">
            {available.length === 0
              ? 'All types added'
              : 'Add a connector…'}
          </option>
          {available.map((c) => (
            <option key={c} value={c}>
              {connectorOptionLabel(c)}
            </option>
          ))}
        </select>
        <button
          type="button"
          disabled={!pick || busy || available.length === 0}
          onClick={() => {
            if (!pick) return
            const u = pick.toUpperCase()
            if (list.some((x) => x.toUpperCase() === u)) return
            saveMutation.mutate([...list, pick])
            setPick('')
          }}
          className="shrink-0 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-semibold text-slate-800 transition enabled:hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100 dark:enabled:hover:bg-slate-800"
        >
          Add
        </button>
        {busy ? (
          <span className="text-xs text-slate-500 dark:text-slate-400">
            Saving…
          </span>
        ) : null}
      </div>

      <p className="text-[11px] leading-relaxed text-slate-500 dark:text-slate-400">
        Add or remove connectors (each change saves immediately). You must keep
        at least one type on the vehicle.
      </p>

      {saveMutation.isError ? (
        <p className="text-xs text-red-600 dark:text-red-400">
          {saveMutation.error instanceof Error
            ? saveMutation.error.message
            : 'Could not update connectors'}
        </p>
      ) : null}
    </div>
  )
}
