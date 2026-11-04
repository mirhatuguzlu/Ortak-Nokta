import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// GitHub Pages proje sayfasında site /<repo>/ altında yayınlanır; iş akışı BASE_PATH verir.
export default defineConfig({
  base: process.env.BASE_PATH ? process.env.BASE_PATH.replace(/\/?$/, '/') : '/',
  plugins: [react()],
})
