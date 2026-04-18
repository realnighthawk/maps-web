import { useEffect, useState } from 'react'
import { useRouteStore } from '../../stores/routeStore'

export function ErrorBanner() {
  const planErrorMessage = useRouteStore((s) => s.planErrorMessage)
  const setPlanErrorMessage = useRouteStore((s) => s.setPlanErrorMessage)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    if (!planErrorMessage) {
      setVisible(false)
      return
    }
    setVisible(true)
    const t = window.setTimeout(() => {
      setVisible(false)
      setPlanErrorMessage(null)
    }, 10_000)
    return () => window.clearTimeout(t)
  }, [planErrorMessage, setPlanErrorMessage])

  if (!planErrorMessage || !visible) return null

  return (
    <div className="pointer-events-auto flex items-start gap-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-900 shadow-sm dark:border-red-900/50 dark:bg-red-950/60 dark:text-red-100">
      <span className="flex-1">{planErrorMessage}</span>
      <button
        type="button"
        className="rounded-md px-2 py-0.5 text-xs font-medium text-red-800 hover:bg-red-100 dark:text-red-200 dark:hover:bg-red-900/40"
        onClick={() => {
          setVisible(false)
          setPlanErrorMessage(null)
        }}
      >
        Dismiss
      </button>
    </div>
  )
}
