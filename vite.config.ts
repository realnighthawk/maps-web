import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const mapsEngine =
    env.MAPS_ENGINE_PROXY_TARGET?.trim() || 'http://127.0.0.1:8080'
  const base = env.VITE_BASE_PATH?.trim() || '/'

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
