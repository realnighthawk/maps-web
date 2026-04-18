import { api } from './client'
import { normalizeTripsResponse } from './normalizeTrips'
import type { Trip, UserMe } from './types'

export async function getTrips(): Promise<Trip[]> {
  const rows = await api.get<unknown>('/trips')
  return normalizeTripsResponse(rows)
}

export function getUserMe(): Promise<UserMe> {
  return api.get<UserMe>('/users/me')
}

export function updateUserMe(body: UserMe): Promise<UserMe> {
  return api.put<UserMe>('/users/me', body)
}

/** Persists `active_vehicle_vin` on the guest user (requires maps-engine + Postgres). */
export async function setActiveVehicleVin(vin: string): Promise<UserMe> {
  const me = await getUserMe()
  return updateUserMe({
    ...me,
    active_vehicle_vin: vin,
  })
}
