import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The client is a static bundle; the game server (src/server) serves it in
// production and proxies nothing. In development Vite serves the client and
// forwards the socket to the server running on PORT (3000 by default).
const serverPort = Number(process.env.PORT ?? 3000);

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist/client',
    emptyOutDir: true,
    target: 'es2020',
    chunkSizeWarningLimit: 900,
  },
  server: {
    host: true,
    port: 5173,
    proxy: {
      '/socket.io': { target: `http://localhost:${serverPort}`, ws: true },
      '/api': { target: `http://localhost:${serverPort}` },
    },
  },
  test: {
    include: ['tests/**/*.test.ts'],
    environment: 'node',
  },
});
