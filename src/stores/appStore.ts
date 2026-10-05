import { create } from 'zustand'

export type Tab = 'route' | 'fleet' | 'trips' | 'settings'
export type ThemePreference = 'system' | 'light' | 'dark'

interface AppState {
  activeTab: Tab
  setActiveTab: (tab: Tab) => void
  theme: ThemePreference
  setTheme: (t: ThemePreference) => void
  wsConnected: boolean
  setWsConnected: (v: boolean) => void
  /** Avoids clobbering ?from=&to= before URL → store hydration finishes. */
  urlRouteHydrated: boolean
  setUrlRouteHydrated: (v: boolean) => void
}

export const useAppStore = create<AppState>((set) => ({
  activeTab: 'route',
  setActiveTab: (tab) => set({ activeTab: tab }),
  theme: 'system',
  setTheme: (theme) => set({ theme }),
  wsConnected: false,
  setWsConnected: (wsConnected) => set({ wsConnected }),
  urlRouteHydrated: false,
  setUrlRouteHydrated: (urlRouteHydrated) => set({ urlRouteHydrated }),
}))
