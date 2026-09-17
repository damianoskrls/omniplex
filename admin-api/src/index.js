// ============================================================
// FILE: src/index.js
// BookUp Admin API — Entry point
// ============================================================

require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const path    = require('path');
const fs      = require('fs');

const authRoutes            = require('./routes/auth.routes');
const mobileAuthRoutes      = require('./routes/mobile_auth.routes');
const tenantRoutes          = require('./routes/tenant.routes');
const businessRoutes        = require('./routes/business.routes');
const bookingRoutes         = require('./routes/booking.routes');
const clientAdminRoutes     = require('./routes/client_admin.routes');
const nutritionRoutes       = require('./routes/nutrition.routes');
const communityRoutes       = require('./routes/community.routes');
const paymentsOnlineRoutes  = require('./routes/payments_online.routes');
const marketplaceRoutes     = require('./routes/marketplace.routes');
const checkinRoutes         = require('./routes/checkin.routes');
const aiRoutes              = require('./routes/ai.routes');
const { startNotificationWorker } = require('./lib/notification_worker');
const { startMessageAttachmentWorker } = require('./lib/message_attachments');
const { bootstrapSchema } = require('./lib/schema_bootstrap');

const app  = express();
const PORT = process.env.PORT || 3001;

// ── Middleware ────────────────────────────────────────────────
app.use(cors({ origin: '*', credentials: false }));
// Raw body for Stripe webhooks (must be before express.json)
app.use('/api/payments-online/:bizId/webhook', express.raw({ type: 'application/json' }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Serve uploaded logos/images as static files
const uploadDir = process.env.UPLOAD_DIR || './uploads';
fs.mkdirSync(uploadDir, { recursive: true });
app.use('/uploads', express.static(path.resolve(uploadDir)));
app.use('/icons', express.static(path.resolve(__dirname, '../public/icons')));

// ── Routes ────────────────────────────────────────────────────
app.use('/api/auth',        authRoutes);
app.use('/api/mobile',      mobileAuthRoutes);
app.use('/api/tenants',     tenantRoutes);
app.use('/api/business',    businessRoutes);
app.use('/api/booking',      bookingRoutes);
app.use('/api/client-admin', clientAdminRoutes);
app.use('/api/mobile/nutrition', nutritionRoutes);
app.use('/api/community', communityRoutes);
app.use('/api/client-admin/community', communityRoutes);
app.use('/api/payments-online', paymentsOnlineRoutes);
app.use('/api/marketplace',     marketplaceRoutes);
app.use('/api/checkin',         checkinRoutes);
app.use('/api/ai',              aiRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.path}` });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: err.message || 'Internal server error' });
});

// ── Start ─────────────────────────────────────────────────────
bootstrapSchema()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`\n Handstand Admin API`);
      console.log(` Running at: http://localhost:${PORT}`);
      console.log(` Health:     http://localhost:${PORT}/api/health\n`);
      startNotificationWorker();
      startMessageAttachmentWorker();
    });
  })
  .catch((err) => {
    console.error('Schema bootstrap failed:', err.message);
    process.exit(1);
  });
