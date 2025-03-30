#!/bin/sh
# Replace placeholders in your static files with runtime environment variables.
# Adjust the file paths and variables as necessary.
envsubst '$VITE_FIREBASE_API_KEY $VITE_FIREBASE_AUTH_DOMAIN $VITE_FIREBASE_PROJECT_ID $VITE_FIREBASE_STORAGE_BUCKET $VITE_FIREBASE_MESSAGING_SENDER_ID $VITE_FIREBASE_APP_ID' < /usr/share/nginx/html/index.html > /usr/share/nginx/html/index.html

# Optionally, repeat the substitution for any other files that require it.

# Start Nginx
exec nginx -g 'daemon off;'
