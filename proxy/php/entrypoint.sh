#!/bin/bash

# Clear and cache various Laravel caches
for cmd in cache:clear route:clear view:clear config:clear view:cache config:cache; do
    cd /var/www/html && /usr/local/bin/php artisan $cmd
done

# Start the cron service in the background
echo "[INFO] Starting cron service..."
cron && echo "[INFO] Cron service started."

# Ensure cron is running by checking its process
if ! pgrep cron; then
    echo "[ERROR] Cron failed to start!"
    exit 1
fi

# Start PHP-FPM as the main process
echo "[INFO] Starting PHP-FPM..."
exec docker-php-entrypoint php-fpm
