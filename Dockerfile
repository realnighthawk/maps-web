# docker build -t ghcr.io/realnighthawk/maps-web:latest \
#   --build-arg VITE_CLERK_PUBLISHABLE_KEY=pk_... --build-arg VITE_GOOGLE_MAPS_API_KEY=... .
FROM docker.io/library/node:22-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ARG VITE_ROUTER_ORIGIN=https://harness-router.nighthawklabs.org
ARG VITE_CLERK_PUBLISHABLE_KEY
ARG VITE_GOOGLE_MAPS_API_KEY
ENV VITE_BASE_PATH=/ VITE_ROUTER_ORIGIN=$VITE_ROUTER_ORIGIN VITE_CLERK_PUBLISHABLE_KEY=$VITE_CLERK_PUBLISHABLE_KEY VITE_GOOGLE_MAPS_API_KEY=$VITE_GOOGLE_MAPS_API_KEY
RUN npm run build

FROM docker.io/nginxinc/nginx-unprivileged:alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html
