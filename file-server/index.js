/**
 * MIS Department Portal — File Upload Server
 *
 * Receives file uploads from Vercel and saves them to /var/www/misapp/uploads/
 * Started via PM2 on port 3001
 * Proxied through Nginx
 */

const express = require('express');
const multer = require('multer');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;
const UPLOAD_DIR = process.env.UPLOAD_DIR || '/var/www/misapp/uploads';
const LOG_DIR = process.env.LOG_DIR || '/var/log/misapp';
const API_KEY = process.env.API_KEY || '';
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',')
  : ['http://localhost:3000', 'http://localhost:3001'];

// Ensure upload directory exists
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  console.log(`✓ Created upload directory: ${UPLOAD_DIR}`);
}

// Ensure log directory exists
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
  console.log(`✓ Created log directory: ${LOG_DIR}`);
}

// Multer storage configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, UPLOAD_DIR);
  },
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    // Sanitize filename: remove special characters, keep only alphanumeric, dots, and hyphens
    const sanitized = file.originalname
      .replace(/[^a-zA-Z0-9.-]/g, '-')
      .replace(/-+/g, '-')
      .toLowerCase();
    const filename = `${timestamp}-${sanitized}`;
    cb(null, filename);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10 MB
  },
  fileFilter: (req, file, cb) => {
    // Allowed MIME types
    const allowedMimes = [
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-excel',
      'text/csv',
    ];

    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`Invalid file type: ${file.mimetype}`), false);
    }
  },
});

// CORS configuration
const corsOptions = {
  origin: (origin, callback) => {
    if (!origin || ALLOWED_ORIGINS.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
};

// Middleware
app.use(cors(corsOptions));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logging
const accessLogStream = fs.createWriteStream(path.join(LOG_DIR, 'access.log'), {
  flags: 'a',
});
app.use(morgan('combined', { stream: accessLogStream }));
app.use(morgan('dev')); // Also log to console in development

// Health check route
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

// Main upload endpoint
app.post('/api/upload', upload.single('file'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        error: 'No file provided',
        details: 'Send a file in the "file" field',
      });
    }

    const fileUrl = `/uploads/${req.file.filename}`;

    console.log(`✓ File uploaded: ${req.file.originalname} → ${req.file.filename}`);

    res.json({
      success: true,
      fileUrl,
      filename: req.file.filename,
      originalName: req.file.originalname,
      size: req.file.size,
      mimeType: req.file.mimetype,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error(`✗ Upload error: ${error.message}`);
    res.status(500).json({
      error: 'Upload failed',
      details: error.message,
    });
  }
});

// Delete file endpoint (for admins)
app.delete('/api/files/:filename', (req, res) => {
  try {
    const { filename } = req.params;

    // Security: prevent directory traversal
    if (filename.includes('..') || filename.includes('/')) {
      return res.status(400).json({
        error: 'Invalid filename',
      });
    }

    const filePath = path.join(UPLOAD_DIR, filename);

    // Ensure file is in upload directory
    if (!filePath.startsWith(UPLOAD_DIR)) {
      return res.status(403).json({
        error: 'Access denied',
      });
    }

    if (!fs.existsSync(filePath)) {
      return res.status(404).json({
        error: 'File not found',
      });
    }

    fs.unlinkSync(filePath);
    console.log(`✓ File deleted: ${filename}`);

    res.json({
      success: true,
      message: 'File deleted',
      filename,
    });
  } catch (error) {
    console.error(`✗ Delete error: ${error.message}`);
    res.status(500).json({
      error: 'Delete failed',
      details: error.message,
    });
  }
});

// List files endpoint (for admins)
app.get('/api/files', (req, res) => {
  try {
    const files = fs.readdirSync(UPLOAD_DIR);
    const fileDetails = files.map((filename) => {
      const filePath = path.join(UPLOAD_DIR, filename);
      const stats = fs.statSync(filePath);
      return {
        filename,
        size: stats.size,
        uploadedAt: stats.birthtime || stats.mtime,
        url: `/uploads/${filename}`,
      };
    });

    res.json({
      success: true,
      total: fileDetails.length,
      files: fileDetails,
    });
  } catch (error) {
    console.error(`✗ List error: ${error.message}`);
    res.status(500).json({
      error: 'Failed to list files',
      details: error.message,
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found',
    path: req.path,
    method: req.method,
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(`✗ Error: ${err.message}`);

  // Multer errors
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({
      error: 'File too large',
      details: 'Maximum file size is 10 MB',
    });
  }

  if (err.code === 'LIMIT_UNEXPECTED_FILE') {
    return res.status(400).json({
      error: 'Unexpected field',
      details: 'Only "file" field is accepted',
    });
  }

  // CORS errors
  if (err.message === 'Not allowed by CORS') {
    return res.status(403).json({
      error: 'CORS error',
      details: 'Origin not allowed',
    });
  }

  res.status(500).json({
    error: 'Internal server error',
    details: err.message,
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════╗
║  MIS File Upload Server                ║
╚════════════════════════════════════════╝

  Port:         ${PORT}
  Upload Dir:   ${UPLOAD_DIR}
  Log Dir:      ${LOG_DIR}
  Node Env:     ${process.env.NODE_ENV || 'development'}
  
  Endpoints:
  POST   /api/upload     — Upload a file
  GET    /api/files      — List uploaded files
  DELETE /api/files/:fn  — Delete a file
  GET    /health         — Health check

  Ready to receive uploads...
`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  process.exit(0);
});
