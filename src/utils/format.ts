export function formatDistance(meters: number): string {
  if (!Number.isFinite(meters) || meters < 0) {
    return '—'
  }
  const miles = meters / 1609.344
  return `${miles.toFixed(0)} mi`
}

export function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  if (h === 0) return `${m}m`
  if (m === 0) return `${h}h`
  return `${h}h ${m}m`
}

/** e.g. 5:48 PM */
export function formatClock(date: Date): string {
  return new Intl.DateTimeFormat('en-US', {
    hour: 'numeric',
    minute: '2-digit',
  }).format(date)
}

export function formatCurrency(dollars: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(dollars)
}

export function formatSoc(percent: number): string {
  return `${Math.round(percent)}%`
}

export function socColor(percent: number): string {
  if (percent < 20) return 'text-red-500'
  if (percent < 40) return 'text-amber-500'
  return 'text-green-500'
}
