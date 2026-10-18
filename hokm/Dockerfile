# Build the client and server, then ship only what runs.
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production PORT=3000 DATA_DIR=/data
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
# Profiles live here. Mount a volume to keep them across restarts; players'
# signed tokens restore their coins even if it's lost.
VOLUME /data
EXPOSE 3000
CMD ["node", "dist/server/index.js"]
