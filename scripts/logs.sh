#!/bin/bash

# View logs from file server and Nginx
# Usage: sudo bash logs.sh

echo "📋 MIS File Server Logs"
echo ""

# Color codes
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== File Server Logs (PM2) ===${NC}"
echo "Run in another terminal: sudo pm2 logs misapp-files"
echo ""

echo -e "${BLUE}=== Nginx Access Logs ===${NC}"
sudo tail -20 /var/log/nginx/misapp-access.log 2>/dev/null || echo "No access logs yet"
echo ""

echo -e "${BLUE}=== Nginx Error Logs ===${NC}"
sudo tail -20 /var/log/nginx/misapp-error.log 2>/dev/null || echo "No errors"
echo ""

echo -e "${BLUE}=== File Server Status ===${NC}"
sudo pm2 list
echo ""

echo -e "${BLUE}=== Disk Usage ===${NC}"
du -sh /var/www/misapp/uploads
