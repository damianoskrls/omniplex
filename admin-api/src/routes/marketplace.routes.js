'use strict';

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const db = require('../db');
const { authenticate } = require('../middleware/auth');
const { requireActiveCustomer } = require('../lib/customer_auth');

const uploadDir = path.resolve(process.env.UPLOAD_DIR || './uploads', 'products');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => cb(null, `${uuidv4()}${path.extname(file.originalname)}`),
});
const upload = multer({ storage, limits: { fileSize: 5 * 1024 * 1024 } });

function softAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header) { req.user = null; return next(); }
  const jwt = require('jsonwebtoken');
  try {
    req.user = jwt.verify(header.replace('Bearer ', ''), process.env.JWT_SECRET || 'secret');
  } catch { req.user = null; }
  next();
}
const { createPaymentIntent } = require('../lib/online_payments');

const router = express.Router();

// ── Mobile: browse products ──────────────────────────────────────────────────

function resolveImageUrl(req, url) {
  if (!url) return null;
  if (url.startsWith('http')) return url;
  const proto = req.headers['x-forwarded-proto'] || req.protocol || 'http';
  const host = req.headers['x-forwarded-host'] || req.headers.host;
  return `${proto}://${host}${url}`;
}

// GET /api/marketplace/:bizId/products
router.get('/:bizId/products', softAuth, async (req, res) => {
  const { category } = req.query;
  try {
    const [products] = await db.query(`
      SELECT id, name, description, category, price_cents, stock, image_url, sort_order
      FROM products
      WHERE business_id = ? AND is_active = 1
        ${category ? 'AND category = ?' : ''}
      ORDER BY sort_order ASC, created_at ASC
    `, category ? [req.params.bizId, category] : [req.params.bizId]);

    const resolved = products.map(p => ({
      ...p,
      image_url: resolveImageUrl(req, p.image_url),
    }));
    return res.json({ products: resolved });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/marketplace/:bizId/products/:productId
router.get('/:bizId/products/:productId', softAuth, async (req, res) => {
  try {
    const [[product]] = await db.query(
      'SELECT * FROM products WHERE id = ? AND business_id = ? AND is_active = 1',
      [req.params.productId, req.params.bizId],
    );
    if (!product) return res.status(404).json({ error: 'Δεν βρέθηκε' });

    // Extra images
    const [extraImages] = await db.query(
      'SELECT id, image_url, sort_order FROM product_images WHERE product_id = ? ORDER BY sort_order ASC',
      [product.id],
    );

    // Build images array: primary first, then extras
    const images = [];
    if (product.image_url) images.push(resolveImageUrl(req, product.image_url));
    for (const img of extraImages) {
      const url = resolveImageUrl(req, img.image_url);
      if (url && !images.includes(url)) images.push(url);
    }

    return res.json({
      ...product,
      image_url: resolveImageUrl(req, product.image_url),
      images,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── Mobile: place order ──────────────────────────────────────────────────────

// POST /api/marketplace/:bizId/orders
// Body: { items: [{ product_id, qty }], notes? }
router.post('/:bizId/orders', softAuth, requireActiveCustomer, async (req, res) => {
  const { items, notes } = req.body;
  if (!items?.length) return res.status(400).json({ error: 'Απαιτούνται items' });

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // Check feature flag
    const [[cfg]] = await conn.query(
      'SELECT feature_marketplace, feature_online_payments FROM business_configs WHERE business_id = ?',
      [req.params.bizId],
    );
    if (!cfg?.feature_marketplace) {
      return res.status(403).json({ error: 'Marketplace δεν είναι ενεργό' });
    }

    // Load and validate products
    const productIds = items.map(i => i.product_id);
    const [products] = await conn.query(
      'SELECT * FROM products WHERE id IN (?) AND business_id = ? AND is_active = 1',
      [productIds, req.params.bizId],
    );
    const productMap = Object.fromEntries(products.map(p => [p.id, p]));

    let totalCents = 0;
    const lineItems = [];
    for (const item of items) {
      const product = productMap[item.product_id];
      if (!product) throw Object.assign(new Error(`Προϊόν ${item.product_id} δεν βρέθηκε`), { status: 404 });
      const qty = Math.max(1, parseInt(item.qty, 10) || 1);
      if (product.stock !== null && product.stock < qty) {
        throw Object.assign(new Error(`Ανεπαρκές απόθεμα για "${product.name}"`), { status: 409 });
      }
      totalCents += product.price_cents * qty;
      lineItems.push({ product, qty });
    }

    // Create order
    const orderId = uuidv4();
    await conn.query(`
      INSERT INTO orders (id, business_id, user_id, status, total_cents, notes)
      VALUES (?, ?, ?, 'pending', ?, ?)
    `, [orderId, req.params.bizId, req.user.userId, totalCents, notes || null]);

    for (const { product, qty } of lineItems) {
      await conn.query(`
        INSERT INTO order_items (id, order_id, product_id, product_name, qty, unit_price_cents)
        VALUES (?, ?, ?, ?, ?, ?)
      `, [uuidv4(), orderId, product.id, product.name, qty, product.price_cents]);

      // Reserve stock
      if (product.stock !== null) {
        await conn.query(
          'UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?',
          [qty, product.id, qty],
        );
      }
    }

    let paymentInfo = null;
    if (cfg.feature_online_payments && totalCents > 0) {
      const [[user]] = await conn.query('SELECT email, full_name FROM users WHERE id = ?', [req.user.userId]);
      try {
        const intent = await createPaymentIntent(conn, req.params.bizId, {
          amountCents: totalCents,
          metadata:    { order_id: orderId, type: 'marketplace' },
          userId:      req.user.userId,
          userEmail:   user?.email,
          userName:    user?.full_name,
        });
        await conn.query(
          'UPDATE orders SET provider = ?, provider_intent_id = ? WHERE id = ?',
          [intent.provider, intent.intent_id, orderId],
        );
        paymentInfo = {
          client_secret:   intent.client_secret,
          intent_id:       intent.intent_id,
          publishable_key: intent.publishable_key,
        };
      } catch (_) {
        // Payment provider not configured — order created but needs manual payment
      }
    }

    await conn.commit();
    return res.status(201).json({
      order_id:    orderId,
      total_cents: totalCents,
      status:      'pending',
      payment:     paymentInfo,
    });
  } catch (err) {
    await conn.rollback();
    return res.status(err.status || 500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// GET /api/marketplace/:bizId/my-orders
router.get('/:bizId/my-orders', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const [orders] = await db.query(`
      SELECT o.id, o.status, o.total_cents, o.created_at, o.mydata_mark,
             JSON_ARRAYAGG(
               JSON_OBJECT('name', oi.product_name, 'qty', oi.qty, 'unit_price_cents', oi.unit_price_cents)
             ) AS items
      FROM orders o
      JOIN order_items oi ON oi.order_id = o.id
      WHERE o.business_id = ? AND o.user_id = ?
      GROUP BY o.id
      ORDER BY o.created_at DESC
    `, [req.params.bizId, req.user.userId]);
    return res.json({ orders });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── Admin: manage products ───────────────────────────────────────────────────

// POST /api/marketplace/:bizId/admin/products
router.post('/:bizId/admin/products', authenticate, async (req, res) => {
  const { name, description, category, price_cents, stock, image_url, sort_order, sku, weight_grams, notes, ingredients, usage_instructions } = req.body;
  if (!name || !price_cents) return res.status(400).json({ error: 'Απαιτούνται name, price_cents' });
  const id = uuidv4();
  try {
    await db.query(`
      INSERT INTO products (id, business_id, name, description, category, price_cents, stock, image_url, sort_order, sku, weight_grams, notes, ingredients, usage_instructions)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [id, req.params.bizId, name, description || null, category || null,
        price_cents, stock ?? null, image_url || null, sort_order || 0,
        sku || null, weight_grams || null, notes || null,
        ingredients || null, usage_instructions || null]);
    return res.status(201).json({ id });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/marketplace/:bizId/admin/products/:productId
router.patch('/:bizId/admin/products/:productId', authenticate, async (req, res) => {
  const allowed = ['name','description','category','price_cents','stock','image_url','sort_order','is_active','sku','weight_grams','notes','ingredients','usage_instructions'];
  const updates = {};
  for (const k of allowed) if (req.body[k] !== undefined) updates[k] = req.body[k];
  if (!Object.keys(updates).length) return res.status(400).json({ error: 'Τίποτα να ενημερωθεί' });
  const sets = Object.keys(updates).map(k => `${k} = ?`).join(', ');
  try {
    await db.query(
      `UPDATE products SET ${sets} WHERE id = ? AND business_id = ?`,
      [...Object.values(updates), req.params.productId, req.params.bizId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/marketplace/:bizId/admin/products/:productId (soft delete)
router.delete('/:bizId/admin/products/:productId', authenticate, async (req, res) => {
  try {
    await db.query(
      'UPDATE products SET is_active = 0 WHERE id = ? AND business_id = ?',
      [req.params.productId, req.params.bizId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/marketplace/:bizId/admin/orders
router.get('/:bizId/admin/orders', authenticate, async (req, res) => {
  const { status, limit = 50, offset = 0 } = req.query;
  try {
    const [orders] = await db.query(`
      SELECT o.id, o.status, o.total_cents, o.created_at, o.notes,
             o.provider_txn_id, o.mydata_mark, o.payment_method, o.source,
             u.full_name AS user_name, u.phone AS user_phone,
             JSON_ARRAYAGG(
               JSON_OBJECT('name', oi.product_name, 'qty', oi.qty, 'price', oi.unit_price_cents)
             ) AS items
      FROM orders o
      LEFT JOIN users u ON u.id = o.user_id
      JOIN order_items oi ON oi.order_id = o.id
      WHERE o.business_id = ?
        ${status ? 'AND o.status = ?' : ''}
      GROUP BY o.id
      ORDER BY o.created_at DESC
      LIMIT ? OFFSET ?
    `, status
       ? [req.params.bizId, status, Number(limit), Number(offset)]
       : [req.params.bizId, Number(limit), Number(offset)]);
    return res.json({ orders });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/marketplace/:bizId/admin/orders/:orderId/status
// Body: { status: 'fulfilled' | 'cancelled' }
router.patch('/:bizId/admin/orders/:orderId/status', authenticate, async (req, res) => {
  const { status } = req.body;
  const VALID = ['pending','paid','fulfilled','cancelled','refunded'];
  if (!VALID.includes(status)) return res.status(400).json({ error: 'Άκυρο status' });
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[order]] = await conn.query(
      'SELECT status FROM orders WHERE id = ? AND business_id = ?',
      [req.params.orderId, req.params.bizId],
    );
    if (!order) return res.status(404).json({ error: 'Παραγγελία δεν βρέθηκε' });

    await conn.query(
      'UPDATE orders SET status = ? WHERE id = ?',
      [status, req.params.orderId],
    );

    // Restore stock if cancelled
    if (status === 'cancelled' && order.status !== 'cancelled') {
      const [items] = await conn.query(
        'SELECT product_id, qty FROM order_items WHERE order_id = ?',
        [req.params.orderId],
      );
      for (const item of items) {
        await conn.query(
          'UPDATE products SET stock = stock + ? WHERE id = ? AND stock IS NOT NULL',
          [item.qty, item.product_id],
        );
      }
    }

    await conn.commit();
    return res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// POST /api/marketplace/:bizId/admin/products/:productId/image
router.post('/:bizId/admin/products/:productId/image', authenticate, upload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Δεν στάλθηκε αρχείο' });
  const url = `/uploads/products/${req.file.filename}`;
  try {
    await db.query('UPDATE products SET image_url = ? WHERE id = ? AND business_id = ?',
      [url, req.params.productId, req.params.bizId]);
    return res.json({ url });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/marketplace/:bizId/admin/products/:productId/images (add extra image)
router.post('/:bizId/admin/products/:productId/images', authenticate, upload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Δεν στάλθηκε αρχείο' });
  const url = `/uploads/products/${req.file.filename}`;
  try {
    const [[maxRow]] = await db.query(
      'SELECT COALESCE(MAX(sort_order),0)+1 AS next FROM product_images WHERE product_id = ?',
      [req.params.productId],
    );
    const id = uuidv4();
    await db.query(
      'INSERT INTO product_images (id, product_id, image_url, sort_order) VALUES (?,?,?,?)',
      [id, req.params.productId, url, maxRow.next],
    );
    return res.json({ id, url });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/marketplace/:bizId/admin/products/:productId/images/:imageId
router.delete('/:bizId/admin/products/:productId/images/:imageId', authenticate, async (req, res) => {
  try {
    const [[img]] = await db.query('SELECT image_url FROM product_images WHERE id = ?', [req.params.imageId]);
    if (img) {
      const filePath = path.resolve(process.env.UPLOAD_DIR || './uploads', img.image_url.replace(/^\//, ''));
      if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
      await db.query('DELETE FROM product_images WHERE id = ? AND product_id = ?',
        [req.params.imageId, req.params.productId]);
    }
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/marketplace/:bizId/admin/orders/in-store
// Body: { items: [{product_id, qty}], customer_name, payment_method: 'cash'|'card', notes? }
router.post('/:bizId/admin/orders/in-store', authenticate, async (req, res) => {
  const { items, customer_name, payment_method, notes } = req.body;
  if (!items?.length) return res.status(400).json({ error: 'Απαιτούνται items' });

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const productIds = items.map(i => i.product_id);
    const [products] = await conn.query(
      'SELECT * FROM products WHERE id IN (?) AND business_id = ? AND is_active = 1',
      [productIds, req.params.bizId],
    );
    const productMap = Object.fromEntries(products.map(p => [p.id, p]));

    let total_cents = 0;
    const lines = [];
    for (const item of items) {
      const p = productMap[item.product_id];
      if (!p) throw new Error(`Προϊόν δεν βρέθηκε: ${item.product_id}`);
      if (p.stock !== null && p.stock < item.qty) throw new Error(`Ανεπαρκές απόθεμα: ${p.name}`);
      lines.push({ product_id: p.id, name: p.name, qty: item.qty, unit_price_cents: p.price_cents });
      total_cents += p.price_cents * item.qty;
    }

    const orderId = uuidv4();
    await conn.query(`
      INSERT INTO orders (id, business_id, user_id, status, total_cents, notes, payment_method, source)
      VALUES (?, ?, NULL, 'fulfilled', ?, ?, ?, 'in_store')
    `, [orderId, req.params.bizId, total_cents,
        [customer_name ? `Πελάτης: ${customer_name}` : 'Πελάτης καταστήματος', notes].filter(Boolean).join(' | '),
        payment_method || 'cash']);

    for (const line of lines) {
      await conn.query(
        'INSERT INTO order_items (id, order_id, product_id, product_name, qty, unit_price_cents) VALUES (?,?,?,?,?,?)',
        [uuidv4(), orderId, line.product_id, line.name, line.qty, line.unit_price_cents],
      );
      if (productMap[line.product_id].stock !== null) {
        await conn.query('UPDATE products SET stock = stock - ? WHERE id = ?', [line.qty, line.product_id]);
      }
    }

    await conn.commit();
    return res.status(201).json({ id: orderId, total_cents });
  } catch (err) {
    await conn.rollback();
    return res.status(400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ── Admin: categories ────────────────────────────────────────────────────────

router.get('/:bizId/admin/categories', authenticate, async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT id, name, sort_order FROM marketplace_categories WHERE business_id = ? ORDER BY sort_order ASC, name ASC',
      [req.params.bizId],
    );
    return res.json({ categories: rows });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

router.post('/:bizId/admin/categories', authenticate, async (req, res) => {
  const { name, sort_order } = req.body;
  if (!name) return res.status(400).json({ error: 'Απαιτείται όνομα' });
  try {
    const id = uuidv4();
    await db.query(
      'INSERT INTO marketplace_categories (id, business_id, name, sort_order) VALUES (?, ?, ?, ?)',
      [id, req.params.bizId, name.trim(), sort_order || 0],
    );
    return res.status(201).json({ id, name: name.trim() });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Υπάρχει ήδη' });
    return res.status(500).json({ error: err.message });
  }
});

router.put('/:bizId/admin/categories/:catId', authenticate, async (req, res) => {
  const { name, sort_order } = req.body;
  try {
    await db.query(
      'UPDATE marketplace_categories SET name = ?, sort_order = ? WHERE id = ? AND business_id = ?',
      [name, sort_order ?? 0, req.params.catId, req.params.bizId],
    );
    return res.json({ ok: true });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

router.delete('/:bizId/admin/categories/:catId', authenticate, async (req, res) => {
  try {
    await db.query('DELETE FROM marketplace_categories WHERE id = ? AND business_id = ?',
      [req.params.catId, req.params.bizId]);
    return res.json({ ok: true });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// ── Admin: marketplace settings (shipping + payment methods) ─────────────────

router.get('/:bizId/admin/settings', authenticate, async (req, res) => {
  try {
    const [[row]] = await db.query(
      'SELECT shipping_json, payment_methods_json FROM marketplace_settings WHERE business_id = ?',
      [req.params.bizId],
    );
    return res.json({
      shipping: row?.shipping_json ? JSON.parse(row.shipping_json) : {},
      payment_methods: row?.payment_methods_json ? JSON.parse(row.payment_methods_json) : { cash: true, card: true, stripe: false },
    });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

router.put('/:bizId/admin/settings', authenticate, async (req, res) => {
  const { shipping, payment_methods } = req.body;
  try {
    await db.query(`
      INSERT INTO marketplace_settings (business_id, shipping_json, payment_methods_json)
      VALUES (?, ?, ?)
      ON DUPLICATE KEY UPDATE
        shipping_json = COALESCE(VALUES(shipping_json), shipping_json),
        payment_methods_json = COALESCE(VALUES(payment_methods_json), payment_methods_json)
    `, [
      req.params.bizId,
      shipping !== undefined ? JSON.stringify(shipping) : null,
      payment_methods !== undefined ? JSON.stringify(payment_methods) : null,
    ]);
    return res.json({ ok: true });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

module.exports = router;
