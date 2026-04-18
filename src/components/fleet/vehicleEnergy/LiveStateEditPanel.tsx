import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useEffect, useMemo, useState } from 'react'
import {
  clampPercent,
  clampToRange,
  vehicleStateWireFromSnapshot,
} from '../../../api/vehicleStateMerge'
import type {
  LiveStateEditBlock,
  LiveStateEditField,
} from '../../../api/vehicleProfile'
import type { VehicleStateWire } from '../../../api/vehicles'
import { putVehicleState } from '../../../api/vehicles'
import { ApiError } from '../../../api/client'

function syncToken(blocks: LiveStateEditBlock[] | undefined) {
  if (!blocks?.length) return ''
  return JSON.stringify(
    blocks.map((b) => b.fields.map((f) => [f.key, f.value])),
  )
}

function applyFieldToWire(
  body: VehicleStateWire,
  field: LiveStateEditField,
  raw: number,
): void {
  switch (field.key) {
    case 'state_of_charge':
      body.state_of_charge = clampPercent(raw)
      break
    case 'battery_temp_c':
      body.battery_temp_c = Number.isFinite(raw) ? raw : 25
      break
    case 'fuel_level':
      body.fuel_level = clampPercent(raw)
      break
    default:
      break
  }
}

function LiveStateFieldControl({
  field,
  value,
  onChange,
}: {
  field: LiveStateEditField
  value: number
  onChange: (n: number) => void
}) {
  const t = field.type.toLowerCase()

  if (t === 'percent') {
    const min = field.min ?? 0
    const max = field.max ?? 100
    const step = field.step ?? 1
    const v = clampToRange(value, min, max)
    return (
      <div className="space-y-2">
        <div className="flex items-baseline justify-between gap-2">
          <span className="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
            {field.label}
          </span>
          <span className="text-lg font-semibold tabular-nums text-slate-900 dark:text-slate-100">
            {Math.round(v)}%
          </span>
        </div>
        <input
          type="range"
          min={min}
          max={max}
          step={step}
          value={v}
          onChange={(e) => onChange(Number(e.target.value))}
          className="w-full accent-slate-900 dark:accent-slate-100"
          aria-label={field.label}
        />
        <input
          type="number"
          min={min}
          max={max}
          step={step}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          className="w-full rounded-lg border border-slate-200 px-2 py-1.5 text-sm dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
        />
      </div>
    )
  }

  if (t === 'number') {
    const step = field.step ?? 1
    return (
      <div>
        <label className="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          {field.label}
        </label>
        <input
          type="number"
          step={step}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          className="mt-1 w-full rounded-lg border border-slate-200 px-2 py-1.5 text-sm dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
        />
      </div>
    )
  }

  return null
}

/**
 * Renders `live_state_edit` from GET /vehicles/{vin}: one control per field `type`,
 * no drivetrain branching in the UI.
 */
export function LiveStateEditPanel({
  vin,
  blocks,
  stateSnapshot,
  drivetrain,
}: {
  vin: string
  blocks: LiveStateEditBlock[] | undefined
  stateSnapshot: VehicleStateWire | Record<string, unknown> | null | undefined
  drivetrain: string
}) {
  const queryClient = useQueryClient()
  const token = useMemo(() => syncToken(blocks), [blocks])

  const [values, setValues] = useState<Record<string, number>>({})
  const [saveError, setSaveError] = useState<string | null>(null)

  useEffect(() => {
    const next: Record<string, number> = {}
    for (const b of blocks ?? []) {
      for (const f of b.fields) {
        next[f.key] = f.value
      }
    }
    setValues(next)
    setSaveError(null)
  }, [vin, drivetrain, token, blocks])

  const save = useMutation({
    mutationFn: async () => {
      const base = vehicleStateWireFromSnapshot(stateSnapshot, drivetrain)
      const body: VehicleStateWire = {
        ...base,
        last_updated_unix: Math.floor(Date.now() / 1000),
      }
      for (const b of blocks ?? []) {
        for (const f of b.fields) {
          const raw = values[f.key]
          if (raw === undefined) continue
          applyFieldToWire(body, f, raw)
        }
      }
      return putVehicleState(vin, body)
    },
    onSuccess: () => {
      setSaveError(null)
      void queryClient.invalidateQueries({ queryKey: ['vehicle', vin, 'detail'] })
      void queryClient.invalidateQueries({ queryKey: ['vehicle', vin] })
      void queryClient.invalidateQueries({ queryKey: ['fleet'] })
    },
    onError: (e: unknown) => {
      if (e instanceof ApiError) setSaveError(e.message)
      else if (e instanceof Error) setSaveError(e.message)
      else setSaveError('Could not save state.')
    },
  })

  if (!blocks?.length) return null

  return (
    <div className="space-y-3">
      {blocks.map((block) => (
        <section
          key={block.title}
          className="rounded-xl border border-slate-200 bg-slate-50/80 dark:border-slate-600 dark:bg-slate-800/50"
        >
          <header className="border-b border-slate-200 px-3 py-2.5 dark:border-slate-600/80">
            <h3 className="text-sm font-semibold text-slate-900 dark:text-slate-100">
              {block.title}
            </h3>
            {block.subtitle ? (
              <p className="mt-0.5 text-xs leading-relaxed text-slate-500 dark:text-slate-400">
                {block.subtitle}
              </p>
            ) : null}
          </header>
          <div className="space-y-4 p-3">
            {block.fields.map((field) => {
              const v = values[field.key]
              if (v === undefined) return null
              return (
                <LiveStateFieldControl
                  key={field.key}
                  field={field}
                  value={v}
                  onChange={(n) =>
                    setValues((prev) => ({ ...prev, [field.key]: n }))
                  }
                />
              )
            })}
          </div>
        </section>
      ))}
      {saveError ? (
        <p className="text-sm text-red-600 dark:text-red-400">{saveError}</p>
      ) : null}
      {save.isSuccess && !saveError ? (
        <p className="text-sm text-emerald-600 dark:text-emerald-400">Saved.</p>
      ) : null}
      <button
        type="button"
        disabled={save.isPending}
        onClick={() => {
          save.reset()
          void save.mutateAsync()
        }}
        className="w-full rounded-lg bg-slate-900 py-2 text-sm font-semibold text-white hover:bg-slate-800 disabled:opacity-50 dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-white"
      >
        {save.isPending ? 'Saving…' : 'Save live state'}
      </button>
    </div>
  )
}
