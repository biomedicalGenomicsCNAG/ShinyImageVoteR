# Build stage
FROM node:20-alpine AS build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Create production build
RUN npm run build

# Serve stage
FROM nginx:alpine

# Copy the build output
COPY --from=build /app/dist /usr/share/nginx/html
COPY replace_env_vars.sh /docker-entrypoint.d/replace_env_vars.sh
COPY entrypoint_run_vite_preview.sh /entrypoint_run_vite_preview.sh

# make the entrypoint script executable
RUN chmod +x /docker-entrypoint.d/replace_env_vars.sh

COPY entrypoint.sh /entrypoint.sh

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]