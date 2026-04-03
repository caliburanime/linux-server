#!/bin/bash

# MIS File Server Setup Script for Arch Linux
# Run this script to automatically set up Node.js, Nginx, and PM2
# Usage: bash setup.sh

set -e  # Exit on error

echo "╔════════════════════════════════════════╗"
echo "║  MIS File Server Setup (Arch Linux)    ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root"
  echo "   Run with: sudo bash setup.sh"
  exit 1
fi

# Step 1: Update system
echo "📦 Step 1: Updating system packages..."
pacman -Syu --noconfirm

# Step 2: Install Node.js and npm
echo "📦 Step 2: Installing Node.js and npm..."
pacman -S --noconfirm nodejs npm

# Step 3: Install Nginx
echo "📦 Step 3: Installing and starting Nginx..."
pacman -S --noconfirm nginx
systemctl enable nginx
systemctl start nginx

# Step 4: Create directories
echo "📁 Step 4: Creating upload directories..."
mkdir -p /var/www/misapp/uploads/{questions,resources,notes,profiles}
chown -R http:http /var/www/misapp
chmod -R 755 /var/www/misapp

# Step 5: Create log directory
echo "📁 Step 5: Creating log directory..."
mkdir -p /var/log/misapp
chown http:http /var/log/misapp
chmod 755 /var/log/misapp

# Step 6: Set up file server
echo "📁 Step 6: Setting up file server..."
if [ -d "/opt/misapp-file-server" ]; then
  echo "   Directory exists, skipping creation"
else
  mkdir -p /opt/misapp-file-server
fi

# Copy file server files from /home/scorpio/calibur/mis-dept-website/linux-server/file-server
PROJECT_DIR="/home/scorpio/calibur/mis-dept-website"
if [ -f "$PROJECT_DIR/linux-server/file-server/index.js" ]; then
  cp "$PROJECT_DIR/linux-server/file-server/index.js" /opt/misapp-file-server/
  cp "$PROJECT_DIR/linux-server/file-server/package.json" /opt/misapp-file-server/
  echo "   Copied file server files"
else
  echo "   ⚠️  Warning: Could not find file-server files at $PROJECT_DIR/linux-server/file-server"
fi

cd /opt/misapp-file-server

# Step 7: Install Node dependencies
echo "📦 Step 7: Installing Node.js dependencies..."
npm install

# Step 8: Create .env file if it doesn't exist
echo "⚙️  Step 8: Creating .env file..."
if [ ! -f ".env" ]; then
  cat > .env <<EOF
NODE_ENV=production
PORT=3001
UPLOAD_DIR=/var/www/misapp/uploads
LOG_DIR=/var/log/misapp
API_KEY=your-secret-api-key-here-change-this
ALLOWED_ORIGINS=https://your-app.vercel.app,https://files.your-domain.com
EOF
  echo "   Created .env file (please update with your values)"
else
  echo "   .env already exists, skipping"
fi

# Step 9: Install PM2
echo "📦 Step 9: Installing PM2..."
npm install -g pm2

# Step 10: Start with PM2
echo "🚀 Step 10: Starting file server with PM2..."
pm2 start index.js --name "misapp-files" --user http
pm2 startup --user http
pm2 save

# Step 11: Copy Nginx config if provided
echo "⚙️  Step 11: Configuring Nginx..."
if [ -f "/home/scorpio/calibur/mis-dept-website/linux-server/nginx/misapp-files.conf" ]; then
  cp /home/scorpio/calibur/mis-dept-website/linux-server/nginx/misapp-files.conf /etc/nginx/sites-available/
  ln -sf /etc/nginx/sites-available/misapp-files.conf /etc/nginx/sites-enabled/
  nginx -t && systemctl reload nginx
  echo "   Nginx configured"
else
  echo "   ⚠️  Nginx config not found at /home/scorpio/calibur/mis-dept-website/linux-server/nginx/, you'll need to copy it manually"
fi

# Final summary
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Setup Complete!                    ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Update /opt/misapp-file-server/.env with your settings:"
echo "   - API_KEY (strong password)"
echo "   - ALLOWED_ORIGINS (your Vercel domain)"
echo ""
echo "2. Configure Nginx domain name in /etc/nginx/sites-available/misapp-files.conf"
echo "   Replace 'files.your-domain.com' and 'your-server-ip'"
echo ""
echo "3. Get SSL certificate (RECOMMENDED):"
echo "   sudo pacman -S certbot certbot-nginx"
echo "   sudo certbot certonly --nginx -d files.your-domain.com"
echo ""
echo "4. Then uncomment SSL lines in nginx config and reload:"
echo "   sudo nginx -t && sudo systemctl reload nginx"
echo ""
echo "5. Test the server:"
echo "   curl http://localhost:3001/health"
echo "   curl http://localhost/uploads/  (via Nginx)"
echo ""
echo "6. View logs:"
echo "   sudo pm2 logs misapp-files"
echo "   sudo tail -f /var/log/nginx/misapp-error.log"
echo ""
echo "✨ Done!"
