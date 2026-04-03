# Architecture & File Organization

Visual guide to understand how everything connects.

**Note:** PostgreSQL database is hosted on Supabase (managed service), not on this Linux server. This server only handles file storage and uploads.

---

## **System Architecture**

```
┌──────────────────────────────────────────────────────────────┐
│                          INTERNET                            │
└──────────────────────────────────┬──────────────────────────┘
                                   │
                    DNS Entry: files.your-domain.com pointing to
                              your-server-ip:443
                                   │
                ┌──────────────────▼──────────────────┐
                │   NGINX (Port 443 + 80)             │
                │   ✓ SSL/TLS certificates            │
                │   ✓ Reverse proxy                   │
                │   ✓ Static file serving             │
                │   ✓ CORS headers                    │
                └────┬──────────────────────┬─────────┘
                     │                      │
        ┌────────────▼──────┐    ┌──────────▼──────┐
        │  POST /api/*      │    │ GET /uploads/*  │
        │  (Reverse proxy)  │    │ (Static files)  │
        │        ↓          │    │        ↓        │
        │  Localhost:3001   │    │ /var/www/misapp/│
        └────────┬──────────┘    │ uploads/        │
                 │               └─────────────────┘
                 │
    ┌────────────▼──────────────────┐
    │   Node.js Express Server      │
    │   (Port 3001 - localhost)     │
    │                               │
    │   ✓ POST /api/upload          │
    │   ✓ GET  /api/files           │
    │   ✓ DELETE /api/files/:name   │
    │   ✓ Multer file handling      │
    │   ✓ CORS & validation         │
    │                               │
    │      ↓ Saves to                │
    │   /var/www/misapp/uploads/    │
    └───────────────────────────────┘


DATABASE: Supabase (Managed PostgreSQL)
   - Hosted remotely (not on this server)
   - Stores file URLs, metadata, user data
   - Connected via Vercel app, not this server


USER FLOW:
──────────

1. Student in Vercel app clicks "Upload File"
              ↓
2. File goes to: https://files.your-domain.com/api/upload
              ↓
3. Nginx sees it's /api/upload → proxies to :3001
              ↓
4. Node.js receives, validates MIME type & size
              ↓
5. Saves to /var/www/misapp/uploads/{timestamp}-{name}.pdf
              ↓
6. Returns {"fileUrl": "/uploads/123456-file.pdf"}
              ↓
7. Vercel app saves URL to PostgreSQL
              ↓
8. Later, when accessing file: Nginx serves directly from disk
```

---

## **File & Folder Structure on Linux Server**

```
/home/scorpio/calibur/
│
├─ mis-dept-website/              [Your Project Root]
│  │
│  ├─ linux-server/               [Server Configuration]
│  │  ├─ README.md
│  │  ├─ SETUP_GUIDE.md
│  │  ├─ START_HERE.md
│  │  ├─ ARCHITECTURE.md
│  │  │
│  │  ├─ file-server/             [Node.js App Source]
│  │  │  ├─ index.js
│  │  │  ├─ package.json
│  │  │  └─ .env.example
│  │  │
│  │  ├─ nginx/
│  │  │  └─ misapp-files.conf
│  │  │
│  │  └─ scripts/
│  │     ├─ setup.sh
│  │     ├─ restart.sh
│  │     ├─ logs.sh
│  │     └─ test-server.sh
│  │
│  └─ ... (other Next.js app files)
│
├─ /var/www/misapp/
│  └─ uploads/                    [Nginx serves from here]
│     ├─ questions/
│     ├─ resources/
│     ├─ notes/
│     ├─ profiles/
│     └─ *.pdf, *.png, etc.       [User uploaded files]
│
├─ /opt/misapp-file-server/       [Node.js Application]
│  ├─ index.js                    [Express server]
│  ├─ package.json
│  ├─ node_modules/
│  └─ .env                        [Environment variables]
│
├─ /var/log/misapp/               [Logs]
│  ├─ access.log
│  └─ error.log
│
├─ /etc/nginx/
│  ├─ sites-available/
│  │  └─ misapp-files.conf        [Nginx config]
│  └─ sites-enabled/
│     └─ misapp-files.conf        [Symlink]
│
├─ /etc/letsencrypt/              [SSL certificates]
│  └─ live/files.your-domain.com/
│     ├─ fullchain.pem
│     └─ privkey.pem
```

---

## **Request Flow Examples**

### **Upload Flow**

```
Client (Vercel) sends:
  POST /api/upload
  Body: multipart/form-data { file }
  To: https://files.your-domain.com/api/upload

        ↓

Nginx receives (port 443):
  ✓ Validates SSL
  ✓ Checks /api/upload pattern
  ✓ Proxies to localhost:3001

        ↓

Node.js receives:
  ✓ Multer parses multipart
  ✓ Validates MIME type (application/pdf, image/*)
  ✓ Checks size (≤ 10 MB)
  ✓ Generates filename: {timestamp}-{sanitized}.ext
  ✓ Saves to /var/www/misapp/uploads/
  ✓ Returns: {"fileUrl": "/uploads/123456-file.pdf"}

        ↓

Client receives response:
  ✓ Stores fileUrl in Supabase (for later retrieval)
  ✓ User can now download via /uploads/
```

### **Download Flow**

```
Client accesses:
  GET /uploads/123456-file.pdf
  From: https://files.your-domain.com

        ↓

Nginx receives (port 443):
  ✓ Validates SSL
  ✓ Checks /uploads/ pattern
  ✓ Looks in /var/www/misapp/uploads/
  ✓ Finds file: 123456-file.pdf
  ✓ Sends file directly (high performance)

        ↓

Client receives:
  File downloaded ✓
```

---

## **Project Folder Structure (Your Laptop)**

```
mis-dept-website/
│
├─ linux-server/                  [NEW - Everything for Linux server]
│  │
│  ├─ START_HERE.md               [Quick overview - read first]
│  ├─ README.md                   [Commands & troubleshooting]
│  ├─ SETUP_GUIDE.md              [Detailed 8-phase walkthrough]
│  ├─ MANUAL_CHECKLIST.md         [Step-by-step with checkboxes]
│  ├─ ARCHITECTURE.md             [This file]
│  │
│  ├─ file-server/                [Node.js Express app]
│  │  ├─ package.json
│  │  ├─ index.js                 [Express server code]
│  │  └─ .env.example
│  │
│  ├─ nginx/                      [Web server config]
│  │  └─ misapp-files.conf
│  │
│  └─ scripts/                    [Helper scripts]
│     ├─ setup.sh                 [Automated setup]
│     ├─ restart.sh
│     ├─ logs.sh
│     └─ test-server.sh
│
├─ app/                           [Your Next.js app]
│  ├─ api/
│  │  ├─ upload/route.ts          [Points to Linux server]
│  │  └─ ...
│  ├─ dashboard/
│  └─ ...
│
├─ prisma/
│  ├─ schema.prisma
│  └─ ...
│
└─ ...

On Linux Server (/home/scorpio/calibur/):
────────────────────────────────────────

mis-dept-website/                → Cloned/copied from your laptop
├─ linux-server/                → Contains all files above
├─ app/                         → Next.js app (for reference)
├─ prisma/                      → Prisma configs (for reference)
├─ package.json
└─ ...
```

---

## **Data Flow Diagram**

```
               Vercel (Next.js App)
               ├─ User uploads file
               │
               └─ API route: POST /api/upload
                  └─ Reads file from browser
                     └─ Sends to: https://files.your-domain.com/api/upload
                        │
                        ├─ Request goes via HTTPS (SSL/TLS)
                        │
                        ├─ DNS resolves: files.your-domain.com → YOUR_SERVER_IP
                        │
                        └─ Arrives at Nginx (port 443)
                           ├─ ✓ Validates SSL certificate
                           │
                           ├─ ✓ Sees /api/upload → routes to :3001
                           │
                           └─ Proxies to Node.js
                              │
                              ├─ ✓ Multer receives file
                              │
                              ├─ ✓ Validates:
                              │   • MIME type (PDF, image, etc.)
                              │   • File size (≤ 10 MB)
                              │
                              ├─ ✓ Saves to:
                              │   /var/www/misapp/uploads/
                              │   {timestamp}-{sanitized-name}.pdf
                              │
                              └─ ✓ Returns JSON response:
                                 {
                                   "fileUrl": "/uploads/1712085600000-file.pdf",
                                   "filename": "1712085600000-file.pdf",
                                   "size": 2048576,
                                   "mimeType": "application/pdf"
                                 }

Next.js receives fileUrl
└─ Saves to Supabase (managed PostgreSQL)
   └─ {courseId, fileUrl, fileType, ...}

Later, when user clicks download:
   → Browser fetches: https://files.your-domain.com/uploads/1712085600000-file.pdf
   → Nginx serves directly (no Node.js involved)
   → High speed: cached, optimized for static files
```

---

## **Service Startup Order**

```
1. Nginx starts on boot
   └─ Listening on :80 and :443

2. PM2 starts file server (via systemctl)
   └─ Node.js :3001 ready to receive uploads

3. Both services running ✓
   └─ Ready for requests from Vercel

Note: Database is Supabase (managed service, starts independently)
```

---

## **Security Layers**

```
┌──────────────────────────────────────┐
│  HTTPS / SSL/TLS (Port 443)          │  ← Encrypts data in transit
├──────────────────────────────────────┤
│  CORS Headers                        │  ← Restricts to your domains
├──────────────────────────────────────┤
│  MIME Type Validation                │  ← Only PDFs, images allowed
├──────────────────────────────────────┤
│  File Size Limit (10 MB)             │  ← Prevents attacks
├──────────────────────────────────────┤
│  Filename Sanitization               │  ← Prevents path traversal
├──────────────────────────────────────┤
│  Nginx Access/Error Logs             │  ← Tracks all requests
└──────────────────────────────────────┘
```

---

## **Monitoring & Debugging**

```
Problem                 → Check This
─────────────────────────────────────────────────────
Upload fails           → sudo pm2 logs misapp-files
                       → sudo tail -f /var/log/nginx/misapp-error.log

File not found         → ls -la /var/www/misapp/uploads/
                       → curl http://localhost/uploads/filename

502 Bad Gateway        → sudo pm2 list (is Node.js running?)
                       → sudo systemctl status nginx

Can't connect Vercel   → Check DNS: nslookup files.your-domain.com
                       → Check firewall: sudo ufw allow 443
                       → Check ALLOWED_ORIGINS in .env
```

---

**That's it! You now have a complete mental model of how the system works. 🎉**

Next step: Read `START_HERE.md` and run the setup script!
