import { useRouteStore } from '../../stores/routeStore'

/** Non-blocking hint while a route is being planned (map stays interactive). */
export function LoadingOverlay() {
  const isPlanning = useRouteStore((s) => s.isPlanning)
  if (!isPlanning) return null
  return (
    <div
      className="pointer-events-none fixed left-1/2 top-3 z-[60] -translate-x-1/2"
      role="status"
      aria-live="polite"
      aria-label="Planning route"
    >
      <div className="h-1 w-52 overflow-hidden rounded-full bg-slate-200/90 dark:bg-slate-700/90">
        <div className="h-full w-2/5 animate-pulse rounded-full bg-blue-500" />
      </div>
    </div>
  )
}
