# Use official NGINX image as base
FROM nginx:1.19.7-alpine

# Install coreutils, sudo, nano, bash, bash-completion, and zsh
RUN apk add --no-cache coreutils sudo nano bash bash-completion zsh

# Set working directory
WORKDIR /var/www/html

# Create directories for logs and ensure they have the correct permissions
RUN mkdir -p /var/www/html/storage/logs && \
    chmod -R 755 /var/www/html/storage && \
    mkdir -p /var/log/nginx && \
    chmod -R 755 /var/log/nginx

# Copy NGINX configuration file into the container
ADD ./proxy/nginx/default.conf.template /etc/nginx/templates/default.conf.template

# Copy all the files from the current directory to the container
COPY . .

# Expose port 80
EXPOSE 80

# Run NGINX in foreground (docker needs this to keep container running)
CMD ["nginx", "-g", "daemon off;"]
