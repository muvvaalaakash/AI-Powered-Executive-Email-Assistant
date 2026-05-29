# Stage 1: Build React SPA
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
# Run clean npm install
RUN npm ci || npm install

COPY . .

# Set VITE_API_URL to empty for relative proxying in production
ARG VITE_API_URL=""
ENV VITE_API_URL=$VITE_API_URL

RUN npm run build

# Stage 2: Serve React via Nginx
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
