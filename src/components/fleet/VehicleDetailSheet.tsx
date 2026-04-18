import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useCallback, useEffect, useId, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import {
  getVehicleDetail,
  updateVehicleProfile,
} from '../../api/vehicles'
import type {
  VehicleDetailResponse,
  VehicleProfileWire,
} from '../../api/vehicleProfile'
import { VehicleConnectorsEditor } from './VehicleConnectorsEditor'
import { LiveStateEditPanel } from './vehicleEnergy/LiveStateEditPanel'

function drivetrainLabel(code: string): string {
  switch (code) {
    case 'EV':
      return 'Battery EV'
    case 'PHEV':
      return 'Plug-in hybrid'
    case 'ICE':
      return 'Gas / diesel'
    default:
      return code || '—'
  }
}

function fuelGradeLabel(v: string | undefined): string {
  if (!v) return '—'
  switch (v) {
    case 'REGULAR':
      return 'Regular'
    case 'PREMIUM':
      return 'Premium'
    case 'DIESEL':
      return 'Diesel'
    default:
      return v
  }
}

function fmtNum(n: number | undefined, suffix = ''): string {
  if (n === undefined || n === null || Number.isNaN(n)) return '—'
  return `${n}${suffix}`
}

function DetailSection({
  title,
  subtitle,
  children,
}: {
  title: string
  subtitle?: string
  children: React.ReactNode
}) {
  return (
    <section className="rounded-xl border border-slate-200 bg-slate-50/80 dark:border-slate-600 dark:bg-slate-800/50">
      <header className="border-b border-slate-200 px-3 py-2.5 dark:border-slate-600/80">
        <h3 className="text-sm font-semibold text-slate-900 dark:text-slate-100">
          {title}
        </h3>
        {subtitle ? (
          <p className="mt-0.5 text-xs leading-relaxed text-slate-500 dark:text-slate-400">
            {subtitle}
          </p>
        ) : null}
      </header>
      <dl className="divide-y divide-slate-200/90 px-3 dark:divide-slate-600/60">
        {children}
      </dl>
    </section>
  )
}

function DetailRow({
  label,
  value,
  mono,
  actions,
}: {
  label: string
  value: React.ReactNode
  mono?: boolean
  actions?: React.ReactNode
}) {
  const display =
    value === '' || value === undefined || value === null ? '—' : value

  return (
    <div className="grid grid-cols-1 gap-1 py-2.5 sm:grid-cols-[minmax(0,40%)_1fr] sm:items-baseline sm:gap-3">
      <dt className="flex items-center gap-2 text-[11px] font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
        <span>{label}</span>
        {actions ? <span className="sm:hidden">{actions}</span> : null}
      </dt>
      <dd className="flex min-w-0 items-start justify-between gap-2 sm:justify-end">
        <span
          className={`min-w-0 break-words text-sm text-slate-900 dark:text-slate-100 ${mono ? 'font-mono text-xs tracking-wide' : ''}`}
        >
          {display}
        </span>
        {actions ? <span className="hidden shrink-0 sm:block">{actions}</span> : null}
      </dd>
    </div>
  )
}

function CopyTextButton({ text, label }: { text: string; label: string }) {
  const [copied, setCopied] = useState(false)

  const copy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 2000)
    } catch {
      /* ignore */
    }
  }, [text])

  return (
    <button
      type="button"
      onClick={copy}
      className="shrink-0 rounded-md px-2 py-0.5 text-[11px] font-semibold text-slate-600 transition hover:bg-slate-200/80 hover:text-slate-900 dark:text-slate-400 dark:hover:bg-slate-700/80 dark:hover:text-slate-100"
      aria-label={`${label} — copy to clipboard`}
    >
      {copied ? 'Copied' : 'Copy'}
    </button>
  )
}

function FieldSkeleton() {
  return (
    <div className="animate-pulse space-y-0 divide-y divide-slate-200/80 dark:divide-slate-600/50">
      {[1, 2, 3, 4, 5].map((i) => (
        <div key={i} className="flex gap-3 py-3">
          <div className="h-3 w-24 rounded bg-slate-200/80 dark:bg-slate-700/60" />
          <div className="h-3 flex-1 rounded bg-slate-200/80 dark:bg-slate-700/60" />
        </div>
      ))}
    </div>
  )
}

interface VehicleDetailSheetProps {
  vin: string | null
  onClose: () => void
}

export function VehicleDetailSheet({ vin, onClose }: VehicleDetailSheetProps) {
  const queryClient = useQueryClient()
  const titleId = useId()
  const closeBtnRef = useRef<HTMLButtonElement>(null)
  const closeTimeoutRef = useRef<number | null>(null)
  const [panelEntered, setPanelEntered] = useState(false)
  const [planMinSoc, setPlanMinSoc] = useState(15)
  const [planChargeTo, setPlanChargeTo] = useState(80)
  const [rangeKm, setRangeKm] = useState('')
  const [planSaveError, setPlanSaveError] = useState<string | null>(null)

  const { data, isLoading, isError, error } = useQuery({
    queryKey: ['vehicle', vin, 'detail'],
    queryFn: () => getVehicleDetail(vin!),
    enabled: Boolean(vin),
  })

  useEffect(() => {
    if (!vin) {
      setPanelEntered(false)
      return
    }
    setPanelEntered(false)
    const id = requestAnimationFrame(() => setPanelEntered(true))
    return () => cancelAnimationFrame(id)
  }, [vin])

  const closePanel = useCallback(() => {
    setPanelEntered(false)
    if (closeTimeoutRef.current != null) {
      window.clearTimeout(closeTimeoutRef.current)
    }
    closeTimeoutRef.current = window.setTimeout(() => {
      closeTimeoutRef.current = null
      onClose()
    }, 280)
  }, [onClose])

  useEffect(
    () => () => {
      if (closeTimeoutRef.current != null) {
        window.clearTimeout(closeTimeoutRef.current)
      }
    },
    [],
  )

  useEffect(() => {
    if (!vin) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') closePanel()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [vin, closePanel])

  useEffect(() => {
    if (!vin || !panelEntered || isLoading) return
    closeBtnRef.current?.focus()
  }, [vin, panelEntered, isLoading])

  if (!vin) return null

  const p: VehicleProfileWire | undefined =
    data?.profile && data.profile.vin === vin ? data.profile : undefined

  const isEV = p
    ? p.drivetrain === 'EV' || p.drivetrain === 'PHEV'
    : false
  const isICE = p ? p.drivetrain === 'ICE' : false

  const displayTitle = p
    ? [p.make, p.model].filter(Boolean).join(' ').trim() || 'Vehicle'
    : 'Vehicle'

  useEffect(() => {
    if (!p || p.vin !== vin) return
    setPlanMinSoc(
      p.planning_min_soc_percent != null && p.planning_min_soc_percent > 0
        ? p.planning_min_soc_percent
        : 15,
    )
    setPlanChargeTo(
      p.planning_charge_to_percent != null && p.planning_charge_to_percent > 0
        ? p.planning_charge_to_percent
        : 80,
    )
    if (p.epa_range_miles != null && p.epa_range_miles > 0) {
      setRangeKm(String(Math.round(p.epa_range_miles / 0.621371)))
    } else {
      setRangeKm('')
    }
  }, [vin, p])

  const planningSave = useMutation({
    mutationFn: async () => {
      if (!p || p.vin !== vin) {
        throw new Error('Vehicle profile not loaded')
      }
      const km = Number.parseFloat(rangeKm.replace(/,/g, '.').trim())
      if (!Number.isFinite(km) || km <= 0) {
        throw new Error('Enter a valid range in km (greater than 0).')
      }
      if (planChargeTo < planMinSoc) {
        throw new Error('Charge-to % must be at least the minimum SoC %.')
      }
      const cached = queryClient.getQueryData<VehicleDetailResponse>([
        'vehicle',
        vin,
        'detail',
      ])
      const prof: VehicleProfileWire =
        cached?.profile?.vin === vin ? cached.profile : p
      return updateVehicleProfile(vin, {
        ...prof,
        planning_min_soc_percent: planMinSoc,
        planning_charge_to_percent: planChargeTo,
        epa_range_miles: km * 0.621371,
      })
    },
    onSuccess: () => {
      setPlanSaveError(null)
      void queryClient.invalidateQueries({
        queryKey: ['vehicle', vin, 'detail'],
      })
      void queryClient.invalidateQueries({ queryKey: ['vehicle', vin] })
      void queryClient.invalidateQueries({ queryKey: ['fleet'] })
    },
    onError: (e: Error) => {
      setPlanSaveError(e.message)
    },
  })

  return createPortal(
    <div className="pointer-events-none fixed inset-0 z-[100]">
      <button
        type="button"
        aria-label="Close vehicle details"
        className={`pointer-events-auto fixed inset-0 bg-slate-950/45 transition-opacity duration-300 ease-out dark:bg-slate-950/55 ${
          panelEntered ? 'opacity-100' : 'opacity-0'
        }`}
        onClick={closePanel}
      />
      <aside
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className={`pointer-events-auto fixed inset-y-0 right-0 flex w-full max-w-md flex-col border-l border-slate-200/80 bg-white/95 shadow-[0_0_40px_-12px_rgba(15,23,42,0.35)] backdrop-blur-sm transition-transform duration-300 ease-out dark:border-slate-700/80 dark:bg-slate-900/95 dark:shadow-[0_0_48px_-12px_rgba(0,0,0,0.5)] ${
          panelEntered ? 'translate-x-0' : 'translate-x-full'
        }`}
        onClick={(e) => e.stopPropagation()}
      >
        <header className="shrink-0 border-b border-slate-200/80 px-4 pb-3 pt-4 dark:border-slate-700/80">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0 flex-1">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                Fleet vehicle
              </p>
              <h2
                id={titleId}
                className="mt-1 truncate text-lg font-semibold text-slate-900 dark:text-slate-100"
              >
                {displayTitle}
              </h2>
              <p className="mt-1 font-mono text-[10px] text-slate-500 dark:text-slate-400">
                {vin}
              </p>
            </div>
            <button
              ref={closeBtnRef}
              type="button"
              onClick={closePanel}
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg text-slate-600 transition hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
              aria-label="Close"
            >
              <svg
                className="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                strokeWidth={2}
                stroke="currentColor"
                aria-hidden
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M6 18 18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
          {p ? (
            <div className="mt-2 flex flex-wrap gap-2">
              <span className="inline-flex items-center rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-700 dark:bg-slate-800 dark:text-slate-200">
                {drivetrainLabel(p.drivetrain)}
              </span>
              {p.year > 0 ? (
                <span className="inline-flex items-center rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-700 dark:bg-slate-800 dark:text-slate-200">
                  {p.year}
                </span>
              ) : null}
            </div>
          ) : null}
        </header>

        <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-3">
          {isLoading && <FieldSkeleton />}
          {isError && (
            <div className="rounded-xl border border-red-200 bg-red-50/90 p-3 text-sm text-red-800 dark:border-red-900/50 dark:bg-red-950/40 dark:text-red-200">
              {error instanceof Error ? error.message : 'Failed to load vehicle'}
            </div>
          )}
          {!isLoading && !isError && data && p && (
            <div className="space-y-3">
              <DetailSection
                title="Profile"
                subtitle="Registered vehicle data from the server."
              >
                <DetailRow
                  label="VIN"
                  value={p.vin}
                  mono
                  actions={<CopyTextButton text={p.vin} label="VIN" />}
                />
                <DetailRow label="Make" value={p.make || undefined} />
                <DetailRow label="Model" value={p.model || undefined} />
                <DetailRow
                  label="Year"
                  value={p.year > 0 ? p.year : undefined}
                />
                <DetailRow
                  label="Drivetrain"
                  value={drivetrainLabel(p.drivetrain)}
                />
              </DetailSection>

              <LiveStateEditPanel
                vin={vin}
                blocks={data.live_state_edit}
                stateSnapshot={data.state}
                drivetrain={p.drivetrain}
              />

              {isEV && (
                <DetailSection
                  title="Electric"
                  subtitle="Battery and charging parameters used for planning."
                >
                  <div className="grid grid-cols-1 gap-2 py-2.5 sm:grid-cols-[minmax(0,40%)_1fr] sm:items-start sm:gap-3">
                    <dt className="text-[11px] font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                      Connectors
                    </dt>
                    <dd className="min-w-0">
                      <VehicleConnectorsEditor vin={vin} profile={p} />
                    </dd>
                  </div>
                  <div className="border-t border-slate-200/90 px-0 py-3 dark:border-slate-600/60">
                    <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                      Trip planning
                    </p>
                    <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
                      Used for route estimates and charging stops. Stored on this
                      vehicle.
                    </p>
                    <div className="mt-3 grid grid-cols-2 gap-3">
                      <div>
                        <label className="text-xs text-slate-500 dark:text-slate-400">
                          Min SoC (%)
                        </label>
                        <input
                          type="number"
                          min={0}
                          max={100}
                          value={planMinSoc}
                          onChange={(e) =>
                            setPlanMinSoc(Number(e.target.value))
                          }
                          className="mt-1 w-full rounded-lg border border-slate-200 px-2 py-1.5 text-sm dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
                        />
                      </div>
                      <div>
                        <label className="text-xs text-slate-500 dark:text-slate-400">
                          Charge to (%)
                        </label>
                        <input
                          type="number"
                          min={0}
                          max={100}
                          value={planChargeTo}
                          onChange={(e) =>
                            setPlanChargeTo(Number(e.target.value))
                          }
                          className="mt-1 w-full rounded-lg border border-slate-200 px-2 py-1.5 text-sm dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
                        />
                      </div>
                    </div>
                    <div className="mt-3">
                      <label className="text-xs text-slate-500 dark:text-slate-400">
                        Range (km)
                      </label>
                      <input
                        type="number"
                        min={1}
                        step={1}
                        inputMode="numeric"
                        value={rangeKm}
                        onChange={(e) => setRangeKm(e.target.value)}
                        placeholder="e.g. 400"
                        className="mt-1 w-full rounded-lg border border-slate-200 px-2 py-1.5 text-sm dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
                      />
                      <p className="mt-0.5 text-[11px] text-slate-500 dark:text-slate-400">
                        Saved as EPA miles on the server for consumption
                        estimates.
                      </p>
                    </div>
                    {planSaveError ? (
                      <p className="mt-2 text-sm text-red-600 dark:text-red-400">
                        {planSaveError}
                      </p>
                    ) : null}
                    {planningSave.isSuccess && !planSaveError ? (
                      <p className="mt-2 text-sm text-emerald-600 dark:text-emerald-400">
                        Planning preferences saved.
                      </p>
                    ) : null}
                    <button
                      type="button"
                      disabled={planningSave.isPending}
                      onClick={() => {
                        setPlanSaveError(null)
                        planningSave.reset()
                        void planningSave.mutateAsync().catch(() => {
                          /* onError sets planSaveError */
                        })
                      }}
                      className="mt-3 w-full rounded-lg border border-slate-300 bg-white py-2 text-sm font-semibold text-slate-800 hover:bg-slate-50 disabled:opacity-50 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 dark:hover:bg-slate-700"
                    >
                      {planningSave.isPending
                        ? 'Saving…'
                        : 'Save trip planning'}
                    </button>
                  </div>
                  <DetailRow
                    label="Battery"
                    value={
                      p.battery_capacity_kwh != null
                        ? `${p.battery_capacity_kwh} kWh`
                        : undefined
                    }
                  />
                  <DetailRow
                    label="Max charge"
                    value={
                      p.max_charge_power_kw != null
                        ? `${p.max_charge_power_kw} kW`
                        : undefined
                    }
                  />
                  <DetailRow
                    label="EPA vehicle ID"
                    value={fmtNum(p.epa_vehicle_id)}
                    mono
                  />
                </DetailSection>
              )}

              {isICE && (
                <DetailSection
                  title="ICE"
                  subtitle="Tank and fuel-economy parameters used for planning."
                >
                  <DetailRow
                    label="Tank"
                    value={
                      p.fuel_tank_size_liters != null
                        ? `${p.fuel_tank_size_liters} L`
                        : undefined
                    }
                  />
                  <DetailRow
                    label="Fuel grade"
                    value={fuelGradeLabel(p.fuel_grade)}
                  />
                  <DetailRow
                    label="EPA MPG (city)"
                    value={fmtNum(p.epa_mpg_city)}
                  />
                  <DetailRow
                    label="EPA MPG (hwy)"
                    value={fmtNum(p.epa_mpg_highway)}
                  />
                </DetailSection>
              )}

              {data?.state && Object.keys(data.state).length > 0 && (
                <details className="rounded-xl border border-slate-200 bg-slate-50/80 dark:border-slate-600 dark:bg-slate-800/50">
                  <summary className="cursor-pointer px-3 py-2.5 text-sm font-semibold text-slate-900 dark:text-slate-100">
                    Raw live state (debug)
                  </summary>
                  <div className="border-t border-slate-200 p-3 dark:border-slate-600/80">
                    <pre
                      tabIndex={0}
                      className="max-h-52 overflow-auto rounded-lg border border-slate-200 bg-white p-3 font-mono text-[10px] leading-relaxed text-slate-600 dark:border-slate-600 dark:bg-slate-900/60 dark:text-slate-400"
                    >
                      {JSON.stringify(data.state, null, 2)}
                    </pre>
                  </div>
                </details>
              )}
            </div>
          )}
        </div>

        {!isLoading && !isError && data && p && (
          <footer className="shrink-0 border-t border-slate-200/80 bg-white/95 px-4 py-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] dark:border-slate-700/80 dark:bg-slate-900/95">
            <button
              type="button"
              onClick={closePanel}
              className="w-full rounded-lg bg-slate-900 py-2.5 text-sm font-semibold text-white transition hover:bg-slate-800 dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-white"
            >
              Done
            </button>
          </footer>
        )}

        {!isLoading && isError && (
          <footer className="shrink-0 border-t border-slate-200/80 bg-white/95 px-4 py-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] dark:border-slate-700/80 dark:bg-slate-900/95">
            <button
              type="button"
              onClick={closePanel}
              className="w-full rounded-lg bg-slate-900 py-2.5 text-sm font-semibold text-white transition hover:bg-slate-800 dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-white"
            >
              Close
            </button>
          </footer>
        )}
      </aside>
    </div>,
    document.body,
  )
}
