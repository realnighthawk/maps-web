import { create } from 'zustand'
import type { VehicleStatus } from '../api/types'

interface FleetState {
  vehicles: VehicleStatus[]
  /** VIN for the vehicle profile panel (sibling to FleetView in App layout). */
  fleetDetailVin: string | null
  setVehicles: (vehicles: VehicleStatus[]) => void
  setFleetDetailVin: (vin: string | null) => void
  upsertVehicle: (vehicle: VehicleStatus) => void
}

export const useFleetStore = create<FleetState>((set) => ({
  vehicles: [],
  fleetDetailVin: null,
  setVehicles: (vehicles) => set({ vehicles }),
  setFleetDetailVin: (vin) => set({ fleetDetailVin: vin }),
  upsertVehicle: (vehicle) =>
    set((state) => {
      const i = state.vehicles.findIndex((v) => v.vin === vehicle.vin)
      if (i < 0) return { vehicles: [...state.vehicles, vehicle] }
      const next = [...state.vehicles]
      next[i] = vehicle
      return { vehicles: next }
    }),
}))
