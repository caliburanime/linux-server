#!/bin/bash

# Restart the file server and Nginx
# Usage: sudo bash restart.sh

echo "🔄 Restarting MIS file server..."

# Restart Node.js server
sudo pm2 restart misapp-files
echo "✓ File server restarted"

# Reload Nginx
sudo systemctl reload nginx
echo "✓ Nginx reloaded"

echo ""
echo "Status:"
sudo pm2 list
echo ""
echo "✅ Done"
