import { useEffect, useRef } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useFleetStore } from '../stores/fleetStore'
import { useAppStore } from '../stores/appStore'
import type { VehicleStatus } from '../api/types'

/** maps-engine `FleetHub.Broadcast` event types that should trigger a fleet refetch. */
const ENGINE_FLEET_EVENT_TYPES = new Set([
  'state_updated',
  'state_changed',
  'telemetry',
  'trip_planned',
])

function parseFleetMessage(raw: unknown): VehicleStatus[] | null {
  if (!raw || typeof raw !== 'object') return null
  const o = raw as Record<string, unknown>
  if (Array.isArray(o.vehicles)) {
    return o.vehicles as VehicleStatus[]
  }
  if (o.type === 'fleet_snapshot' && Array.isArray(o.payload)) {
    return o.payload as VehicleStatus[]
  }
  if (o.type === 'vehicle_update' && o.vehicle) {
    return [o.vehicle as VehicleStatus]
  }
  return null
}

const MAX_DELAY_MS = 30_000

export function useFleetWebSocket(enabled: boolean) {
  const queryClient = useQueryClient()
  const setVehicles = useFleetStore((s) => s.setVehicles)
  const upsertVehicle = useFleetStore((s) => s.upsertVehicle)
  const setWsConnected = useAppStore((s) => s.setWsConnected)
  const attemptRef = useRef(0)
  const wsRef = useRef<WebSocket | null>(null)
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    if (!enabled) {
      setWsConnected(false)
      return
    }

    let stopped = false

    const connect = () => {
      if (stopped) return
      const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
      const host = window.location.host
      const url = `${proto}//${host}/api/v1/fleet/live`

      try {
        const ws = new WebSocket(url)
        wsRef.current = ws

        ws.onopen = () => {
          if (stopped) return
          attemptRef.current = 0
          setWsConnected(true)
        }

        ws.onmessage = (ev) => {
          try {
            const data = JSON.parse(ev.data as string) as unknown
            if (data && typeof data === 'object') {
              const t = (data as { type?: unknown }).type
              if (typeof t === 'string' && ENGINE_FLEET_EVENT_TYPES.has(t)) {
                const vin = (data as { vehicleVin?: unknown }).vehicleVin
                void queryClient.invalidateQueries({ queryKey: ['fleet'] })
                if (t === 'trip_planned') {
                  void queryClient.invalidateQueries({ queryKey: ['trips'] })
                }
                if (typeof vin === 'string' && vin.length > 0) {
                  void queryClient.invalidateQueries({
                    queryKey: ['vehicle', vin],
                  })
                }
                return
              }
            }
            const list = parseFleetMessage(data)
            if (!list) return
            if (list.length === 1 && (data as { type?: string }).type === 'vehicle_update') {
              upsertVehicle(list[0]!)
            } else {
              setVehicles(list)
            }
          } catch {
            /* ignore malformed */
          }
        }

        ws.onerror = () => {
          setWsConnected(false)
        }

        ws.onclose = () => {
          if (stopped) return
          setWsConnected(false)
          wsRef.current = null
          const n = ++attemptRef.current
          const delay = Math.min(1000 * 2 ** Math.min(n, 5), MAX_DELAY_MS)
          timerRef.current = setTimeout(connect, delay)
        }
      } catch {
        setWsConnected(false)
        const n = ++attemptRef.current
        const delay = Math.min(1000 * 2 ** Math.min(n, 5), MAX_DELAY_MS)
        timerRef.current = setTimeout(connect, delay)
      }
    }

    connect()

    return () => {
      stopped = true
      if (timerRef.current) clearTimeout(timerRef.current)
      wsRef.current?.close()
      wsRef.current = null
      setWsConnected(false)
    }
  }, [enabled, queryClient, setVehicles, upsertVehicle, setWsConnected])
}
