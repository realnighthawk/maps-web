import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

function resolveBase(env: Record<string, string>): string {
  const explicit = env.VITE_BASE_PATH?.trim()
  if (explicit) return explicit
  // GitHub Actions sets this; default project Pages URL is /<repo>/
  const ghRepo = process.env.GITHUB_REPOSITORY
  if (ghRepo) {
    const name = ghRepo.split('/')[1]
    if (name) return `/${name}/`
  }
  return '/'
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const mapsEngine =
    env.MAPS_ENGINE_PROXY_TARGET?.trim() || 'http://127.0.0.1:8080'
  const base = resolveBase(env)

  return {
    base,
    plugins: [react()],
    server: {
      proxy: {
        '/api': {
          target: mapsEngine,
          changeOrigin: true,
          ws: true,
        },
      },
    },
  }
})
