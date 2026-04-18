import { useEffect, useState } from 'react'
import { useAppStore } from '../stores/appStore'

export function useResolvedDark(): boolean {
  const theme = useAppStore((s) => s.theme)
  const [systemDark, setSystemDark] = useState(() =>
    typeof window !== 'undefined'
      ? window.matchMedia('(prefers-color-scheme: dark)').matches
      : false,
  )

  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    const onChange = () => setSystemDark(mq.matches)
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [])

  if (theme === 'dark') return true
  if (theme === 'light') return false
  return systemDark
}

export function useDarkClassSync() {
  const isDark = useResolvedDark()
  useEffect(() => {
    document.documentElement.classList.toggle('dark', isDark)
  }, [isDark])
  return isDark
}
