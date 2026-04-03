# Linux Server Setup Guide — MIS Department Portal

Complete step-by-step guide for Arch Linux with Node.js + Nginx file server.

**Project Location:** `/home/scorpio/calibur/mis-dept-website`

**Database:** Supabase (managed PostgreSQL, not self-hosted)

---

## **Before You Start**

```bash
# SSH into your Linux server
ssh scorpio@your-server.com

# Navigate to project folder
cd /home/scorpio/calibur/mis-dept-website/linux-server

# All steps below assume you're in this directory
```

---

## **System Requirements**

- Arch Linux (with `pacman`)
- Root or sudo access
- Domain name (optional for local testing, required for production)
- 1GB RAM minimum, 2GB recommended

---

## **Phase 1: Install Dependencies (Arch Linux)**

### Step 1.1: Update system

```bash
sudo pacman -Syu
```

### Step 1.2: Install Node.js and npm

```bash
sudo pacman -S nodejs npm
node --version    # Should be v18+
npm --version
```

### Step 1.3: Install Nginx

```bash
sudo pacman -S nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

---

## **Phase 2: Create Upload Directory & Nginx Config**

### Step 2.1: Create directories

```bash
# Main upload directory
sudo mkdir -p /var/www/misapp/uploads
sudo mkdir -p /var/www/misapp/uploads/questions
sudo mkdir -p /var/www/misapp/uploads/resources
sudo mkdir -p /var/www/misapp/uploads/notes
sudo mkdir -p /var/www/misapp/uploads/profiles

# Set permissions (nginx user)
sudo chown -R http:http /var/www/misapp
sudo chmod -R 755 /var/www/misapp
```

### Step 2.2: Copy Nginx configuration

```bash
# Backup original config
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

# Copy our config from project directory
sudo cp /home/scorpio/calibur/mis-dept-website/linux-server/nginx/misapp-files.conf /etc/nginx/sites-available/

# Enable the site
sudo ln -s /etc/nginx/sites-available/misapp-files.conf /etc/nginx/sites-enabled/

# Test config
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

---

## **Phase 3: Set Up Node.js File Server**

### Step 3.1: Create application directory

```bash
sudo mkdir -p /opt/misapp-file-server
cd /opt/misapp-file-server
```

### Step 3.2: Copy file server files

```bash
# Copy from /home/scorpio/calibur/mis-dept-website/linux-server/file-server to /opt/misapp-file-server
sudo cp -r /home/scorpio/calibur/mis-dept-website/linux-server/file-server/* /opt/misapp-file-server/

# Set proper permissions
sudo chown -R http:http /opt/misapp-file-server
sudo chmod 755 /opt/misapp-file-server

# Install dependencies
cd /opt/misapp-file-server
npm install
```

### Step 3.3: Create .env file

```bash
cat > /opt/misapp-file-server/.env <<EOF
NODE_ENV=production
PORT=3001
UPLOAD_DIR=/var/www/misapp/uploads
LOG_DIR=/var/log/misapp
API_KEY=your-secret-api-key-here
ALLOWED_ORIGINS=https://your-app.vercel.app,https://files.your-domain.com
EOF
```

### Step 3.4: Create log directory

```bash
sudo mkdir -p /var/log/misapp
sudo chown http:http /var/log/misapp
sudo chmod 755 /var/log/misapp
```

---

## **Phase 4: Set Up PM2 Process Manager**

PM2 keeps your Node.js server running 24/7 and restarts it automatically.

### Step 4.1: Install PM2 globally

```bash
sudo npm install -g pm2

# For Arch Linux, you may need to set npm to use sudo
npm config set prefix '/usr'
```

### Step 4.2: Start the file server with PM2

```bash
cd /opt/misapp-file-server
sudo pm2 start index.js --name "misapp-files" --user http

# Make it auto-start on reboot
sudo pm2 startup
sudo pm2 save

# Verify it's running
sudo pm2 list
```

### Step 4.3: Monitor the server

```bash
# View logs
sudo pm2 logs misapp-files

# View dashboard
sudo pm2 monit
```

---

## **Phase 5: Configure Nginx Reverse Proxy**

The Nginx config already includes reverse proxy setup. Here's what it does:

```nginx
# POST /api/upload → Node.js server on :3001
location /api/upload {
  proxy_pass http://localhost:3001;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
}

# GET /uploads/* → Static file serving
location /uploads/ {
  alias /var/www/misapp/uploads/;
  try_files $uri =404;
}
```

---

## **Phase 6: SSL/TLS with Let's Encrypt (Optional but Recommended)**

### Step 6.1: Install Certbot

```bash
sudo pacman -S certbot certbot-nginx
```

### Step 6.2: Get certificate

```bash
sudo certbot certonly --nginx -d files.your-domain.com

# Follow the prompts
# Certificate saved to: /etc/letsencrypt/live/files.your-domain.com/
```

### Step 6.3: Update Nginx config

The Nginx config file already includes SSL comments. Uncomment them and update:

```nginx
listen 443 ssl http2;
listen [::]:443 ssl http2;

ssl_certificate /etc/letsencrypt/live/files.your-domain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/files.your-domain.com/privkey.pem;
```

### Step 6.4: Auto-renew certificates

```bash
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer
```

---

## **Phase 7: Test Everything**

### Step 7.1: Check Nginx is serving files

```bash
# Create a test file
echo "Test file" | sudo tee /var/www/misapp/uploads/test.txt

# Test locally
curl http://localhost/uploads/test.txt
# Should output: "Test file"

# Test from remote
curl http://your-server-ip/uploads/test.txt
```

### Step 7.2: Test file upload endpoint

```bash
# Create a test file on your laptop
echo "Hello from upload" > test.txt

# Upload via cURL
curl -X POST \
  -F "file=@test.txt" \
  http://your-server-ip/api/upload

# Should return:
# {"fileUrl":"/uploads/1712085600000-test.txt","filename":"1712085600000-test.txt"}
```

### Step 7.3: Verify processes are running

```bash
# Check Nginx
sudo systemctl status nginx

# Check Node.js via PM2
sudo pm2 list
```

---

## **Phase 8: Update Vercel Environment Variables**

In Vercel dashboard, add:

```env
NEXT_PUBLIC_FILES_URL=https://files.your-domain.com
DATABASE_URL=postgresql://...  # Your Supabase connection string (from supabase.com)
```

---

## **Common Tasks After Setup**

### View file server logs

```bash
sudo pm2 logs misapp-files
```

### Restart file server (if code changes)

```bash
sudo pm2 restart misapp-files
```

### Check disk space

```bash
df -h
du -sh /var/www/misapp/uploads
```

### Add uploaded files manually via SCP

```bash
# From your laptop
scp my-file.pdf user@your-server.com:/var/www/misapp/uploads/

# Check permissions
ssh user@your-server.com "ls -la /var/www/misapp/uploads/"
```

### Monitor real-time traffic to Nginx

```bash
sudo tail -f /var/log/nginx/access.log
```

---

## **Troubleshooting**

### Nginx shows 404 for files

```bash
# Check if directory exists and has content
ls -la /var/www/misapp/uploads/

# Check Nginx error log
sudo tail -f /var/log/nginx/error.log

# Check Nginx config
sudo nginx -t
```

### File upload returns 502 (Bad Gateway)

```bash
# Check if Node.js is running
sudo pm2 list

# Check if port 3001 is bound
sudo ss -tlnp | grep 3001

# View Node.js logs
sudo pm2 logs misapp-files
```

### Permission denied when saving files

```bash
# Check upload directory permissions
ls -la /var/www/misapp/uploads/

# Fix if needed
sudo chown http:http /var/www/misapp/uploads
sudo chmod 755 /var/www/misapp/uploads
```

---

## **Next Steps**

1. Follow steps 1–4 first (dependencies + directories)
2. Update your DNS: `files.your-domain.com` → your server IP
3. Follow steps 5–7
4. Test with Phase 7
5. Update Vercel env vars in Phase 8
6. Re-deploy Vercel

Questions? Check the **Troubleshooting** section or review `/var/log/nginx/error.log` and `sudo pm2 logs misapp-files`.
