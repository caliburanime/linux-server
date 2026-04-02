# Manual Setup Checklist — Step by Step

Use this if you prefer to run commands manually instead of `setup.sh`.

---

## **Phase 0: Connect to Your Server**

```bash
# SSH to your Linux server
ssh scorpio@your-server.com

# Navigate to project
cd /home/scorpio/calibur/mis-dept-website/linux-server

# All commands below assume you're in this directory
```

- [ ] SSH connection successful
- [ ] Navigated to `/home/scorpio/calibur/mis-dept-website/linux-server`

---

## **Phase 1: Install Dependencies**

### 1.1 Update Arch Linux

```bash
sudo pacman -Syu
```

- [ ] System updated

### 1.2 Install Node.js & npm

```bash
sudo pacman -S nodejs npm
node --version
npm --version
```

- [ ] Node.js installed (v18+)
- [ ] npm installed

### 1.3 Install Nginx

```bash
sudo pacman -S nginx
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl status nginx
```

- [ ] Nginx installed
- [ ] Nginx enabled for auto-start
- [ ] Nginx is running

### 1.4 Verify PostgreSQL

```bash
sudo pacman -S postgresql
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

- [ ] PostgreSQL installed
- [ ] PostgreSQL is running

### 1.5 Create PostgreSQL user & database

```bash
sudo -u postgres psql
```

Then in psql prompt:

```sql
CREATE USER misapp WITH PASSWORD 'strong-password-here';
CREATE DATABASE misapp OWNER misapp;
GRANT ALL PRIVILEGES ON DATABASE misapp TO misapp;
\q
```

Test connection:

```bash
psql -h localhost -U misapp -d misapp -c "SELECT version();"
```

- [ ] PostgreSQL user created: `misapp`
- [ ] Database created: `misapp`
- [ ] Connection tested

---

## **Phase 2: Create Directories**

### 2.1 Create upload directory structure

```bash
sudo mkdir -p /var/www/misapp/uploads/{questions,resources,notes,profiles}
```

- [ ] Upload directories created

### 2.2 Set permissions

```bash
sudo chown -R http:http /var/www/misapp
sudo chmod -R 755 /var/www/misapp
ls -la /var/www/misapp
```

- [ ] Nginx user (http) owns the directory
- [ ] Permissions are correct (755)

### 2.3 Create log directory

```bash
sudo mkdir -p /var/log/misapp
sudo chown http:http /var/log/misapp
sudo chmod 755 /var/log/misapp
```

- [ ] Log directory created
- [ ] Permissions set

---

## **Phase 3: Set Up Node.js File Server**

### 3.1 Create application directory

```bash
sudo mkdir -p /opt/misapp-file-server
cd /opt/misapp-file-server
```

- [ ] Directory created

### 3.2 Copy files from your project

```bash
# On your LOCAL machine, copy from linux-server/file-server/ to Linux server:
scp ~/mis-dept-website/linux-server/file-server/package.json user@your-server:/tmp/
scp ~/mis-dept-website/linux-server/file-server/index.js user@your-server:/tmp/

# On your server, move to /opt:
sudo cp /tmp/package.json /opt/misapp-file-server/
sudo cp /tmp/index.js /opt/misapp-file-server/
sudo chown -R $USER:$USER /opt/misapp-file-server
```

- [ ] package.json copied
- [ ] index.js copied

### 3.3 Install Node dependencies

```bash
cd /opt/misapp-file-server
npm install
```

- [ ] Dependencies installed

### 3.4 Create .env file

```bash
cat > /opt/misapp-file-server/.env <<EOF
NODE_ENV=production
PORT=3001
UPLOAD_DIR=/var/www/misapp/uploads
LOG_DIR=/var/log/misapp
API_KEY=your-random-secret-key-here
ALLOWED_ORIGINS=https://your-app.vercel.app,https://files.your-domain.com
EOF
```

Update with your actual values:

```bash
nano /opt/misapp-file-server/.env
```

- [ ] .env file created
- [ ] Values updated

### 3.5 Test Node.js server locally

```bash
cd /opt/misapp-file-server
npm start &
curl http://localhost:3001/health
```

Kill it: `Ctrl+C` or `pkill -f "node index.js"`

- [ ] Server starts without errors
- [ ] `/health` endpoint responds

---

## **Phase 4: Install PM2 Process Manager**

### 4.1 Install PM2 globally

```bash
sudo npm install -g pm2
pm2 --version
```

- [ ] PM2 installed globally

### 4.2 Start file server with PM2

```bash
cd /opt/misapp-file-server
sudo pm2 start index.js --name "misapp-files" --user http
```

- [ ] File server started with PM2

### 4.3 Enable auto-start on reboot

```bash
sudo pm2 startup
sudo pm2 save
```

Verify:

```bash
sudo pm2 list
```

- [ ] PM2 startup configured
- [ ] Server shows as running in `pm2 list`

### 4.4 Test logging

```bash
sudo pm2 logs misapp-files
```

Should show: "MIS File Upload Server running on :3001"

- [ ] Logs are being captured

---

## **Phase 5: Configure Nginx**

### 5.1 Copy Nginx configuration

```bash
# Copy from your project to server:
scp ~/mis-dept-website/linux-server/nginx/misapp-files.conf user@your-server:/tmp/

# Move to Nginx:
sudo cp /tmp/misapp-files.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/misapp-files.conf /etc/nginx/sites-enabled/
```

- [ ] Config file copied

### 5.2 Update domain in Nginx config

```bash
sudo nano /etc/nginx/sites-available/misapp-files.conf
```

Find and replace:

- `files.your-domain.com` → your actual domain
- `your-server-ip` → your server's IP

- [ ] Domain updated

### 5.3 Test Nginx configuration

```bash
sudo nginx -t
```

Should say: "syntax is ok" and "test is successful"

- [ ] Nginx config is valid

### 5.4 Reload Nginx

```bash
sudo systemctl reload nginx
sudo systemctl status nginx
```

- [ ] Nginx reloaded
- [ ] Nginx is running

---

## **Phase 6: Test Everything**

### 6.1 Health check

```bash
curl http://localhost:3001/health
```

Should return JSON with status "ok"

- [ ] Node.js server is responding

### 6.2 Create test file

```bash
echo "Test file content" | sudo tee /var/www/misapp/uploads/test.txt
```

- [ ] Test file created

### 6.3 Test Nginx file serving

```bash
curl http://localhost/uploads/test.txt
```

Should return: "Test file content"

- [ ] Nginx is serving files

### 6.4 Test upload API

```bash
curl -X POST -F "file=@~/.bashrc" http://localhost:3001/api/upload
```

Should return JSON with `fileUrl` and `filename`

- [ ] Upload API is working

### 6.5 Test download via Nginx

From the upload response, copy the `fileUrl` (e.g., `/uploads/1712085600000-bashrc`)

```bash
curl http://localhost/uploads/1712085600000-bashrc
```

Should return your file content

- [ ] Download working through Nginx

### 6.6 Remote testing (if on different machine)

```bash
bash ~/mis-dept-website/linux-server/scripts/test-server.sh your-server-ip
```

- [ ] Remote test passes

---

## **Phase 7: SSL/TLS Setup (OPTIONAL but RECOMMENDED)**

### 7.1 Install Certbot

```bash
sudo pacman -S certbot certbot-nginx
```

- [ ] Certbot installed

### 7.2 Get certificate

```bash
sudo certbot certonly --nginx -d files.your-domain.com
```

Follow the prompts. Certificate will be saved to `/etc/letsencrypt/live/files.your-domain.com/`

- [ ] Certificate obtained

### 7.3 Update Nginx config

```bash
sudo nano /etc/nginx/sites-available/misapp-files.conf
```

Uncomment these lines:

```nginx
ssl_certificate /etc/letsencrypt/live/files.your-domain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/files.your-domain.com/privkey.pem;
```

And uncomment the `listen 443 ssl http2;` lines

- [ ] SSL lines uncommented

### 7.4 Test and reload

```bash
sudo nginx -t
sudo systemctl reload nginx
```

- [ ] Nginx config still valid
- [ ] Nginx reloaded with SSL

### 7.5 Set up auto-renewal

```bash
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer
```

- [ ] Auto-renewal enabled

---

## **Phase 8: Update Vercel Environment**

### 8.1 Update Vercel env vars

Go to Vercel dashboard → Your Project → Settings → Environment Variables

Add or update:

```
NEXT_PUBLIC_FILES_URL=https://files.your-domain.com
DATABASE_URL=postgresql://misapp:password@your-server-ip:5432/misapp
```

- [ ] NEXT_PUBLIC_FILES_URL set
- [ ] DATABASE_URL set
- [ ] Vercel redeployed

---

## **Phase 9: Final Verification**

```bash
# Check all services
sudo systemctl status nginx
sudo systemctl status postgresql
sudo pm2 list

# Check disk usage
df -h
du -sh /var/www/misapp/uploads

# Test health
curl https://files.your-domain.com/health
```

- [ ] All services running
- [ ] Health check passes
- [ ] Disk space sufficient

---

## **Complete! ✅**

Your file server is now running. Next:

1. Test uploading from Vercel
2. Set up monitoring (optional)
3. Back up your PostgreSQL database regularly
4. Monitor disk space in `/var/www/misapp/uploads`

---

## **Quick Reference Commands**

```bash
# View logs
sudo pm2 logs misapp-files

# Restart services
sudo pm2 restart misapp-files
sudo systemctl reload nginx

# Check status
sudo pm2 list
sudo systemctl status nginx postgresql

# Test upload
curl -X POST -F "file=@test.txt" https://files.your-domain.com/api/upload

# Test download
curl https://files.your-domain.com/uploads/filename.pdf
```

**Questions?** Check [SETUP_GUIDE.md](./SETUP_GUIDE.md) or [README.md](./README.md)
