import { useAppStore, type Tab } from '../../stores/appStore'

const TABS: { id: Tab; label: string }[] = [
  { id: 'route', label: 'Route' },
  { id: 'fleet', label: 'Fleet' },
  { id: 'trips', label: 'Trips' },
  { id: 'settings', label: 'Settings' },
]

export function BottomNav() {
  const activeTab = useAppStore((s) => s.activeTab)
  const setActiveTab = useAppStore((s) => s.setActiveTab)
  const wsConnected = useAppStore((s) => s.wsConnected)

  return (
    <div className="pointer-events-auto flex items-center justify-center gap-1 rounded-full border border-slate-200/90 bg-white/95 px-2 py-2 shadow-lg backdrop-blur-sm dark:border-slate-700/90 dark:bg-slate-900/95">
      {TABS.map((tab) => {
        const active = activeTab === tab.id
        return (
          <button
            key={tab.id}
            type="button"
            onClick={() => setActiveTab(tab.id)}
            className={`rounded-full px-4 py-2 text-sm font-medium transition ${
              active
                ? 'bg-slate-900 text-white dark:bg-slate-100 dark:text-slate-900'
                : 'text-slate-500 hover:text-slate-800 dark:text-slate-400 dark:hover:text-slate-200'
            }`}
          >
            {tab.label}
          </button>
        )
      })}
      <span
        className="ml-1 flex items-center gap-1.5 border-l border-slate-200 pl-3 dark:border-slate-700"
        title={wsConnected ? 'Live fleet connected' : 'Live fleet disconnected'}
      >
        <span
          className={`h-2 w-2 rounded-full ${
            wsConnected ? 'bg-emerald-500' : 'bg-slate-300 dark:bg-slate-600'
          }`}
          aria-hidden
        />
      </span>
    </div>
  )
}
