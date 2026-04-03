# Linux Server Setup — Node.js + Nginx File Server

Complete guide for deploying the MIS Department Portal file server on Arch Linux.

**Database:** Supabase (managed PostgreSQL, not self-hosted)

---

## **Quick Start (5 minutes)**

```bash
# 1. SSH into your Linux server
ssh scorpio@your-server.com

# 2. Navigate to project directory
cd /home/scorpio/calibur/mis-dept-website/linux-server

# 3. Run setup script
sudo bash scripts/setup.sh

# 4. Update .env file
sudo nano /opt/misapp-file-server/.env

# 5. Test it
bash scripts/test-server.sh your-server-ip
```

That's it! The file server will be running on port 3001, proxied through Nginx.

---

## **Detailed Setup (See [SETUP_GUIDE.md](./SETUP_GUIDE.md))**

The full guide covers:

- Phase 1: Install dependencies (Node.js, Nginx on Arch Linux)
- Phase 2: Create directories & Nginx config
- Phase 3: Node.js file server
- Phase 4: PM2 process manager
- Phase 5: Nginx reverse proxy
- Phase 6: SSL/TLS with Let's Encrypt
- Phase 7: Testing
- Phase 8: Update Vercel env vars

---

## **Files in This Folder**

```
linux-server/
├── SETUP_GUIDE.md              ← Full setup documentation
├── README.md                   ← This file
│
├── file-server/
│   ├── package.json            ← Dependencies
│   ├── index.js                ← Express.js file upload server
│   └── .env.example            ← Environment variables template
│
├── nginx/
│   └── misapp-files.conf       ← Nginx configuration
│
└── scripts/
    ├── setup.sh                ← Automated setup (run once)
    ├── restart.sh              ← Restart services
    ├── logs.sh                 ← View logs
    └── test-server.sh          ← Test upload & download
```

---

## **What Gets Installed?**

| Component         | Purpose                                 | Port            |
| ----------------- | --------------------------------------- | --------------- |
| **Node.js + npm** | JavaScript runtime                      | —               |
| **Nginx**         | Web server + reverse proxy              | 80, 443         |
| **PM2**           | Process manager (keeps Node.js running) | —               |
| **Express.js**    | File upload API                         | 3001 (internal) |

---

## **Architecture Diagram**

```
┌─────────────────────────────────────────────┐
│           Vercel (Your App)                 │
│  https://your-app.vercel.app               │
└────────────────┬────────────────────────────┘
                 │ (upload request)
                 │
        ┌────────▼─────────────┐
        │  Nginx (Port 443)    │
        │  ✓ Reverse proxy     │
        │  ✓ SSL/TLS           │
        │  ✓ Static files      │
        └────────┬──────┬──────┘
                 │      │
      ┌──────────▼┐    │
      │ Node.js  │    │
      │ :3001    │    │  (if /api/upload)
      │ (Receives│
      │  files)  │    │
      └──────────┘    │
                      │
        ┌─────────────▼─────┐
        │ /var/www/misapp   │
        │ /uploads/         │
        │ (Stored files)    │
        └───────────────────┘
```

---

## **Commands to Remember**

### View status

```bash
sudo pm2 list              # File server status
sudo systemctl status nginx # Nginx status
```

### View logs

```bash
sudo pm2 logs misapp-files  # Real-time file server logs
sudo tail -f /var/log/nginx/misapp-error.log        # Nginx errors
sudo tail -f /var/log/nginx/misapp-access.log       # Nginx requests
```

### Upload a file manually

```bash
curl -X POST -F "file=@my-file.pdf" http://localhost:3001/api/upload
```

### Download a file

```bash
curl http://your-server-ip/uploads/filename.pdf
```

### Restart everything

```bash
sudo bash scripts/restart.sh
```

---

## **HTTPS/SSL Setup (Recommended)**

After initial setup, add SSL:

```bash
# Install certbot
sudo pacman -S certbot certbot-nginx

# Get certificate
sudo certbot certonly --nginx -d files.your-domain.com

# Uncomment these lines in nginx/misapp-files.conf:
# ssl_certificate /etc/letsencrypt/live/files.your-domain.com/fullchain.pem;
# ssl_certificate_key /etc/letsencrypt/live/files.your-domain.com/privkey.pem;

# Reload Nginx
sudo systemctl reload nginx
```

---

## **Environment Variables**

Update `/opt/misapp-file-server/.env`:

```env
NODE_ENV=production
PORT=3001
UPLOAD_DIR=/var/www/misapp/uploads
LOG_DIR=/var/log/misapp
API_KEY=change-me-to-something-secret
ALLOWED_ORIGINS=https://your-app.vercel.app,https://files.your-domain.com
```

---

## **Integration with Vercel**

Update your Vercel environment variables:

```env
NEXT_PUBLIC_FILES_URL=https://files.your-domain.com
DATABASE_URL=postgresql://...  # Your Supabase connection string (from supabase.com)
```

Then in your Next.js upload API:

```typescript
// app/api/upload/route.ts
const formData = new FormData();
formData.append("file", file);

const response = await fetch(
    `${process.env.NEXT_PUBLIC_FILES_URL}/api/upload`,
    {
        method: "POST",
        body: formData,
    },
);

const { fileUrl } = await response.json();
// Save fileUrl to database
```

---

## **Troubleshooting**

### Files not uploading

```bash
# Check Node.js is running
sudo pm2 list

# Check logs
sudo pm2 logs misapp-files

# Check upload directory permissions
ls -la /var/www/misapp/uploads/
```

### 502 Bad Gateway from Nginx

```bash
# Node.js probably crashed
sudo pm2 logs misapp-files

# Restart it
sudo pm2 restart misapp-files
```

### 404 when accessing files

```bash
# Check if files exist
ls -la /var/www/misapp/uploads/

# Check Nginx config
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### Nginx won't start

```bash
# Check syntax
sudo nginx -t

# View errors
sudo systemctl status nginx
sudo journalctl -u nginx -n 20
```

---

## **Monitoring & Maintenance**

### Check disk space

```bash
df -h                    # Overall
du -sh /var/www/misapp   # Uploads directory
```

### Monitor in real-time

```bash
sudo pm2 monit           # File server
# Or
watch -n 1 'du -sh /var/www/misapp/uploads/'
```

### Clean up old logs

```bash
# Nginx logs don't rotate automatically on Arch
# Set up logrotate if needed:
sudo pacman -S logrotate
# Then configure /etc/logrotate.d/nginx
```

---

## **Next Steps**

1. ✅ Run `setup.sh`
2. ✅ Update `.env` file
3. ✅ Test with `test-server.sh`
4. ✅ Get SSL certificate
5. ✅ Update Vercel environment variables
6. ✅ Test file upload from Vercel app
7. ✅ Set up monitoring (optional)

---

## **Support**

If something doesn't work:

1. Check logs: `sudo pm2 logs misapp-files`
2. Test locally: `curl http://localhost:3001/health`
3. Check Nginx: `sudo nginx -t`
4. Review [SETUP_GUIDE.md](./SETUP_GUIDE.md) Troubleshooting section

---

**Last updated:** April 2, 2026
