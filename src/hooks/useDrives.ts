import { useQuery } from '@tanstack/react-query'
import {
  getDriveRoute,
  getDriveSensors,
  getDriveSeries,
  getDriveStats,
  listDrives,
  listGarage,
} from '../api/journeys'

const tz = () => Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'

export const useDrives = () => useQuery({ queryKey: ['drives'], queryFn: () => listDrives(50) })

export const useGarage = () => useQuery({ queryKey: ['garage'], queryFn: listGarage, staleTime: 60_000 })

export const useDriveStats = (days: number) =>
  useQuery({ queryKey: ['drive-stats', days, tz()], queryFn: () => getDriveStats(days, tz()) })

export const useDriveRoute = (id: string | null) =>
  useQuery({ queryKey: ['drive-route', id], queryFn: () => getDriveRoute(id!), enabled: !!id })

export const useDriveSensors = (id: string | null) =>
  useQuery({ queryKey: ['drive-sensors', id], queryFn: () => getDriveSensors(id!), enabled: !!id })

export const useDriveSeries = (id: string | null, pid: string | null) =>
  useQuery({ queryKey: ['drive-series', id, pid], queryFn: () => getDriveSeries(id!, pid!), enabled: !!id && !!pid })
