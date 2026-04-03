# ✅ Linux Server Setup Complete

Everything is ready in the `linux-server/` folder. Here's what was created:

---

## **📁 Folder Structure**

```
linux-server/
├── README.md                      ← Start here
├── SETUP_GUIDE.md                 ← Full documentation (8 phases)
├── MANUAL_CHECKLIST.md            ← Step-by-step manual setup
│
├── file-server/                   ← Node.js file upload server
│   ├── package.json
│   ├── index.js                   ← Express.js server code
│   └── .env.example               ← Environment template
│
├── nginx/
│   └── misapp-files.conf          ← Nginx reverse proxy config
│
└── scripts/                       ← Helper scripts for Linux
    ├── setup.sh                   ← Automatic setup (recommended)
    ├── restart.sh                 ← Restart services
    ├── logs.sh                    ← View logs
    └── test-server.sh             ← Test upload/download
```

---

## **🚀 Quick Setup (Choose One)**

### **Option A: Automatic (Recommended)**

```bash
# SSH into your Linux server
ssh scorpio@your-server.com

# Navigate to your project folder
cd /home/scorpio/calibur/mis-dept-website/linux-server

# Run the setup script
sudo bash scripts/setup.sh

# Update .env with your settings
sudo nano /opt/misapp-file-server/.env

# Test
bash scripts/test-server.sh your-server-ip
```

**Time:** ~5 minutes

### **Option B: Manual Step-by-Step**

Follow [MANUAL_CHECKLIST.md](./MANUAL_CHECKLIST.md) line by line. Good for learning.

**Time:** ~20 minutes

---

## **📋 What Gets Installed**

| Component         | Purpose                    | How                       |
| ----------------- | -------------------------- | ------------------------- |
| **Node.js + npm** | JavaScript runtime         | `pacman -S nodejs npm`    |
| **Nginx**         | Web server + reverse proxy | `pacman -S nginx`         |
| **PM2**           | Process manager            | `npm install -g pm2`      |
| **Express.js**    | File upload API            | `/opt/misapp-file-server` |

**Database:** PostgreSQL is hosted on Supabase (not on this server)

---

## **📝 Configuration Files**

### **1. Node.js Server** (`file-server/index.js`)

Already written. Key features:

- ✅ File upload with validation (10 MB max)
- ✅ File serving endpoint
- ✅ Delete/list endpoints for admins
- ✅ CORS headers configured
- ✅ Error handling & logging
- ✅ Health check endpoint

**Endpoints:**

```
POST   /api/upload      — Upload a file
GET    /api/files       — List uploaded files
DELETE /api/files/:fn   — Delete a file
GET    /health          — Server status
```

### **2. Nginx Config** (`nginx/misapp-files.conf`)

Already written. Key features:

- ✅ Reverses proxy to Node.js (:3001 → /api/\*)
- ✅ Serves static files from `/var/www/misapp/uploads/`
- ✅ HTTP → HTTPS redirect
- ✅ SSL/TLS support (Let's Encrypt)
- ✅ CORS headers
- ✅ Logging

**You need to update:**

- `files.your-domain.com` → your domain
- `your-server-ip` → your IP

### **3. Environment Variables** (`file-server/.env.example`)

Copy to `.env` and update:

```env
NODE_ENV=production
PORT=3001
UPLOAD_DIR=/var/www/misapp/uploads
LOG_DIR=/var/log/misapp
API_KEY=generate-a-strong-key
ALLOWED_ORIGINS=https://your-app.vercel.app,https://files.your-domain.com
```

---

## **🔧 What Happens During Setup**

The `setup.sh` script automatically:

1. ✅ Updates Arch Linux packages
2. ✅ Installs Node.js, npm, Nginx
3. ✅ Creates directories (`/var/www/misapp/uploads/`, `/var/log/misapp`)
4. ✅ Sets correct permissions (nginx user)
5. ✅ Installs Node dependencies (`npm install`)
6. ✅ Creates `.env` file
7. ✅ Installs PM2 globally
8. ✅ Starts file server with PM2
9. ✅ Copies Nginx configuration
10. ✅ Reloads Nginx

---

## **📊 Architecture After Setup**

```
Internet
   ↓
Nginx (Port 443 — HTTPS)
   ├─→ POST /api/upload → Node.js (:3001)
   │                        ↓
   │                   Saves to /var/www/misapp/uploads/
   │
   └─→ GET /uploads/* → Static files from /var/www/misapp/uploads/

Vercel App
   ├─→ Fetch from https://files.your-domain.com (Nginx)
   └─→ Upload to https://files.your-domain.com/api/upload (Node.js)
```

---

## **🧪 Testing**

After setup, test locally on the server:

```bash
# 1. Health check
curl http://localhost:3001/health

# 2. Create test file
echo "test" | sudo tee /var/www/misapp/uploads/test.txt

# 3. Download via Nginx
curl http://localhost/uploads/test.txt

# 4. Upload via API
curl -X POST -F "file=@~/.bashrc" http://localhost:3001/api/upload
```

Or test from your laptop:

```bash
bash linux-server/scripts/test-server.sh your-server-ip
```

---

## **🔐 Integration with Vercel**

### **Step 1: Update Vercel Environment Variables**

Dashboard → Settings → Environment Variables

```
NEXT_PUBLIC_FILES_URL=https://files.your-domain.com
DATABASE_URL=postgresql://...  # Your Supabase connection string (from supabase.com)
```

### **Step 2: Update Your Next.js Upload API**

```typescript
// app/api/upload/route.ts (or wherever you handle uploads)

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
await prisma.question.create({
    data: {
        fileUrl, // e.g., "/uploads/1712085600000-file.pdf"
        fileType,
        // ... other fields
    },
});
```

### **Step 3: Download Files in Your UI**

```typescript
// In your components
<a href={`${process.env.NEXT_PUBLIC_FILES_URL}${fileUrl}`} target="_blank">
  Download PDF
</a>
```

---

## **🛠️ Common Tasks After Setup**

### **View logs**

```bash
sudo pm2 logs misapp-files
# or
sudo tail -f /var/log/nginx/misapp-error.log
```

### **Restart after changes**

```bash
sudo bash linux-server/scripts/restart.sh
```

### **Check status**

```bash
sudo pm2 list
sudo systemctl status nginx
```

### **Upload file manually**

```bash
curl -X POST -F "file=@my-file.pdf" \
  https://files.your-domain.com/api/upload
```

### **Add SSL certificate**

```bash
sudo pacman -S certbot certbot-nginx
sudo certbot certonly --nginx -d files.your-domain.com
# Then uncomment SSL lines in nginx config
sudo systemctl reload nginx
```

---

## **⚠️ Important Notes**

1. **Make scripts executable** (if needed):

    ```bash
    chmod +x linux-server/scripts/*.sh
    ```

2. **Update .env file** with your actual values before starting

3. **DNS setup:** Point `files.your-domain.com` to your server IP

4. **Database:** Use Supabase for PostgreSQL (not this server)

5. **Monitoring:** Check disk space periodically
    ```bash
    du -sh /var/www/misapp/uploads/
    ```

---

## **📚 Next Reading**

1. **README.md** — Overview & commands
2. **SETUP_GUIDE.md** — Detailed 8-phase walkthrough
3. **MANUAL_CHECKLIST.md** — Step-by-step with checkboxes

---

## **❓ Troubleshooting**

### File upload returns 502 (Bad Gateway)

- Check Node.js: `sudo pm2 list`
- Check logs: `sudo pm2 logs misapp-files`
- Restart: `sudo pm2 restart misapp-files`

### Files not accessible (404)

- Check directory: `ls -la /var/www/misapp/uploads/`
- Check Nginx: `sudo nginx -t && sudo systemctl reload nginx`

More troubleshooting in **SETUP_GUIDE.md** → Troubleshooting section

---

## **✨ You're Ready!**

Everything is set up. Next steps:

1. [ ] SSH into your Linux server
2. [ ] Copy `linux-server/` folder there
3. [ ] Run `sudo bash scripts/setup.sh`
4. [ ] Update `.env` file
5. [ ] Update Vercel env vars
6. [ ] Test upload from Vercel
7. [ ] Monitor with `sudo pm2 logs misapp-files`

**Questions?** All answers are in the docs above. Good luck! 🚀
