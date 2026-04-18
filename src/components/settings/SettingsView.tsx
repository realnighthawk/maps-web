import { useAppStore } from '../../stores/appStore'

export function SettingsView() {
  const theme = useAppStore((s) => s.theme)
  const setTheme = useAppStore((s) => s.setTheme)

  return (
    <div className="pointer-events-auto max-h-[min(520px,calc(100vh-10rem))] w-full max-w-sm overflow-y-auto rounded-2xl border border-slate-200/80 bg-white/95 p-4 shadow-xl backdrop-blur-sm dark:border-slate-700/80 dark:bg-slate-900/95">
      <h2 className="text-lg font-semibold text-slate-900 dark:text-slate-100">
        Settings
      </h2>

      <div className="mt-4">
        <label className="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          Appearance
        </label>
        <select
          value={theme}
          onChange={(e) =>
            setTheme(e.target.value as 'system' | 'light' | 'dark')
          }
          className="mt-1 w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
        >
          <option value="system">Match system</option>
          <option value="light">Light</option>
          <option value="dark">Dark</option>
        </select>
      </div>
    </div>
  )
}
