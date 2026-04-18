interface PlanButtonProps {
  disabled: boolean
  loading: boolean
  hasPlannedRoute: boolean
  onClick: () => void
}

export function PlanButton({
  disabled,
  loading,
  hasPlannedRoute,
  onClick,
}: PlanButtonProps) {
  const label = hasPlannedRoute ? 'Replan' : 'Plan route'
  return (
    <button
      type="button"
      disabled={disabled || loading}
      onClick={onClick}
      className="mt-3 w-full rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50 dark:bg-blue-500 dark:hover:bg-blue-600"
    >
      {loading ? (
        <span className="inline-flex items-center justify-center gap-2">
          <span
            className="h-4 w-4 animate-spin rounded-full border-2 border-white/40 border-t-white"
            aria-hidden
          />
          Planning…
        </span>
      ) : (
        label
      )}
    </button>
  )
}
