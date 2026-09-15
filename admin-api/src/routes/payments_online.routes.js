'use strict';

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const { authenticate } = require('../middleware/auth');
const { requireActiveCustomer } = require('../lib/customer_auth');

function softAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header) { req.user = null; return next(); }
  const jwt = require('jsonwebtoken');
  try {
    req.user = jwt.verify(header.replace('Bearer ', ''), process.env.JWT_SECRET || 'secret');
  } catch { req.user = null; }
  next();
}
const {
  createPaymentIntent, confirmPayment, parseWebhook,
  markPaymentPaid, refundPayment,
} = require('../lib/online_payments');
const { loadMydataConfig, submitReceipt } = require('../lib/mydata');

const router = express.Router();

// ── Mobile: initiate payment ─────────────────────────────────────────────────

// POST /api/payments-online/:bizId/intent
// Body: { payment_id }  — the pre-created manual payment row to pay online
router.post('/:bizId/intent', softAuth, requireActiveCustomer, async (req, res) => {
  const { payment_id } = req.body;
  if (!payment_id) return res.status(400).json({ error: 'Απαιτείται payment_id' });

  const conn = await db.getConnection();
  try {
    const [[payment]] = await conn.query(`
      SELECT p.*, u.email, u.full_name, u.phone
      FROM payments p
      JOIN users u ON u.id = p.user_id
      WHERE p.id = ? AND p.business_id = ? AND p.user_id = ?
    `, [payment_id, req.params.bizId, req.user.userId]);

    if (!payment) return res.status(404).json({ error: 'Πληρωμή δεν βρέθηκε' });
    if (payment.status === 'paid') return res.status(409).json({ error: 'Έχει ήδη πληρωθεί' });

    const balance = payment.amount_cents - (payment.paid_amount_cents || 0);
    if (balance <= 0) return res.status(409).json({ error: 'Δεν υπάρχει υπόλοιπο' });

    const result = await createPaymentIntent(conn, req.params.bizId, {
      amountCents: balance,
      metadata:    { payment_id, type: 'gym_payment' },
      userId:      req.user.userId,
      userEmail:   payment.email,
      userName:    payment.full_name,
    });

    // Store intent_id on the payment row so webhook can find it
    await conn.query(
      'UPDATE payments SET provider_intent_id = ?, provider = ? WHERE id = ?',
      [result.intent_id, result.provider, payment_id],
    );

    return res.json({
      client_secret:   result.client_secret,
      intent_id:       result.intent_id,
      publishable_key: result.publishable_key,
      amount_cents:    balance,
    });
  } catch (err) {
    return res.status(err.status || 500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// POST /api/payments-online/:bizId/confirm
// Body: { payment_id, intent_id } — called after Stripe confirms on client
router.post('/:bizId/confirm', softAuth, requireActiveCustomer, async (req, res) => {
  const { payment_id, intent_id } = req.body;
  if (!payment_id || !intent_id) return res.status(400).json({ error: 'Απαιτούνται payment_id, intent_id' });

  const conn = await db.getConnection();
  try {
    const { status, charge_id } = await confirmPayment(conn, req.params.bizId, intent_id);
    if (status !== 'succeeded') {
      return res.status(402).json({ error: 'Η πληρωμή δεν ολοκληρώθηκε', stripe_status: status });
    }

    await markPaymentPaid(conn, req.params.bizId, payment_id, {
      providerTxnId: charge_id || intent_id,
      intentId:      intent_id,
      provider:      'stripe',
    });

    return res.json({ ok: true, status: 'paid' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ── Stripe Webhook ───────────────────────────────────────────────────────────

// POST /api/payments-online/:bizId/webhook/stripe
// Must use raw body — see index.js for bodyParser config
router.post('/:bizId/webhook/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
  const signature = req.headers['stripe-signature'];
  if (!signature) return res.status(400).send('Missing stripe-signature');

  const conn = await db.getConnection();
  try {
    const event = await parseWebhook(conn, req.params.bizId, {
      rawBody:   req.body,
      signature,
    });

    if (event.type === 'payment_intent.succeeded') {
      const intent = event.data.object;
      const paymentId = intent.metadata?.payment_id;
      const orderId   = intent.metadata?.order_id;

      if (paymentId) {
        await markPaymentPaid(conn, req.params.bizId, paymentId, {
          providerTxnId: intent.latest_charge || intent.id,
          intentId:      intent.id,
          provider:      'stripe',
        });
      }

      if (orderId) {
        await conn.query(`
          UPDATE orders
          SET status = 'paid', provider_txn_id = ?, updated_at = NOW()
          WHERE id = ? AND business_id = ?
        `, [intent.latest_charge || intent.id, orderId, req.params.bizId]);

        // myDATA for marketplace order
        const mydataCfg = await loadMydataConfig(conn, req.params.bizId);
        if (mydataCfg?.is_enabled) {
          const [[order]] = await conn.query(
            'SELECT total_cents FROM orders WHERE id = ?', [orderId],
          );
          try {
            const { mark, uid } = await submitReceipt(mydataCfg, {
              grossCents:   order.total_cents,
              description:  'Αγορά marketplace',
              issueDate:    new Date().toISOString().slice(0, 10),
              seriesNumber: `M/${orderId.slice(0, 6).toUpperCase()}`,
            });
            if (mark) {
              await conn.query(
                'UPDATE orders SET mydata_mark = ?, mydata_uid = ? WHERE id = ?',
                [mark, uid, orderId],
              );
            }
          } catch (e) {
            console.error('[myDATA] order webhook:', e.message);
          }
        }
      }
    }

    res.json({ received: true });
  } catch (err) {
    console.error('[stripe-webhook]', err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
  } finally {
    conn.release();
  }
});

// ── Admin: provider config ───────────────────────────────────────────────────

// GET /api/payments-online/:bizId/config
router.get('/:bizId/config', authenticate, async (req, res) => {
  try {
    const [providers] = await db.query(
      'SELECT provider, is_active, config FROM payment_providers WHERE business_id = ?',
      [req.params.bizId],
    );
    const [[mydataRow]] = await db.query(
      'SELECT is_enabled, vat_number, tax_authority, legal_name, address, invoice_type, vat_category, is_production FROM mydata_config WHERE business_id = ?',
      [req.params.bizId],
    );
    const [[featureRow]] = await db.query(
      'SELECT feature_online_payments FROM business_configs WHERE business_id = ?',
      [req.params.bizId],
    );
    return res.json({
      feature_online_payments: !!featureRow?.feature_online_payments,
      providers: providers.map(p => ({
        provider:    p.provider,
        is_active:   !!p.is_active,
        has_config:  !!p.config,
        publishable_key: (typeof p.config === 'string' ? JSON.parse(p.config) : p.config)?.publishable_key || null,
      })),
      mydata: mydataRow || null,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PUT /api/payments-online/:bizId/provider/stripe
// Body: { secret_key, publishable_key, webhook_secret, is_active }
router.put('/:bizId/provider/stripe', authenticate, async (req, res) => {
  const { secret_key, publishable_key, webhook_secret, is_active } = req.body;
  if (!secret_key || !publishable_key) {
    return res.status(400).json({ error: 'Απαιτούνται secret_key και publishable_key' });
  }
  const config = JSON.stringify({ secret_key, publishable_key, webhook_secret: webhook_secret || null });
  const id = uuidv4();
  try {
    await db.query(`
      INSERT INTO payment_providers (id, business_id, provider, is_active, config)
      VALUES (?, ?, 'stripe', ?, ?)
      ON DUPLICATE KEY UPDATE is_active = VALUES(is_active), config = VALUES(config)
    `, [id, req.params.bizId, is_active ? 1 : 0, config]);

    if (is_active) {
      await db.query(
        'UPDATE business_configs SET feature_online_payments = 1 WHERE business_id = ?',
        [req.params.bizId],
      );
    }
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PUT /api/payments-online/:bizId/mydata
// Body: myDATA config fields
router.put('/:bizId/mydata', authenticate, async (req, res) => {
  const {
    is_enabled, aade_user_id, aade_subscription_key,
    vat_number, tax_authority, legal_name, address,
    is_production, invoice_type, vat_category,
  } = req.body;
  const id = uuidv4();
  try {
    await db.query(`
      INSERT INTO mydata_config
        (id, business_id, is_enabled, aade_user_id, aade_subscription_key,
         vat_number, tax_authority, legal_name, address, is_production, invoice_type, vat_category)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        is_enabled = VALUES(is_enabled),
        aade_user_id = VALUES(aade_user_id),
        aade_subscription_key = VALUES(aade_subscription_key),
        vat_number = VALUES(vat_number),
        tax_authority = VALUES(tax_authority),
        legal_name = VALUES(legal_name),
        address = VALUES(address),
        is_production = VALUES(is_production),
        invoice_type = COALESCE(VALUES(invoice_type), invoice_type),
        vat_category = COALESCE(VALUES(vat_category), vat_category)
    `, [
      id, req.params.bizId,
      is_enabled ? 1 : 0, aade_user_id || null, aade_subscription_key || null,
      vat_number || null, tax_authority || null, legal_name || null,
      address || null, is_production ? 1 : 0,
      invoice_type || '11.1', vat_category || 1,
    ]);
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/payments-online/:bizId/mydata/resubmit/:paymentId
// Retry myDATA submission for a payment that failed
router.post('/:bizId/mydata/resubmit/:paymentId', authenticate, async (req, res) => {
  const conn = await db.getConnection();
  try {
    const [[payment]] = await conn.query(
      'SELECT amount_cents, description FROM payments WHERE id = ? AND business_id = ? AND status = ?',
      [req.params.paymentId, req.params.bizId, 'paid'],
    );
    if (!payment) return res.status(404).json({ error: 'Πληρωμή δεν βρέθηκε ή δεν είναι paid' });

    const mydataCfg = await loadMydataConfig(conn, req.params.bizId);
    if (!mydataCfg?.is_enabled) return res.status(400).json({ error: 'myDATA δεν είναι ενεργό' });

    const { mark, uid } = await submitReceipt(mydataCfg, {
      grossCents:   payment.amount_cents,
      description:  payment.description,
      issueDate:    new Date().toISOString().slice(0, 10),
      seriesNumber: req.params.paymentId.slice(0, 8).toUpperCase(),
    });

    await conn.query(`
      UPDATE payments SET mydata_mark = ?, mydata_uid = ?,
        mydata_invoice_type = ?, mydata_submitted_at = NOW()
      WHERE id = ?
    `, [mark, uid, mydataCfg.invoice_type || '11.1', req.params.paymentId]);

    return res.json({ ok: true, mark, uid });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// Admin: refund a payment
router.post('/:bizId/refund/:paymentId', authenticate, async (req, res) => {
  const conn = await db.getConnection();
  try {
    const result = await refundPayment(conn, req.params.bizId, req.params.paymentId);
    return res.json({ ok: true, ...result });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ── Mobile: payment options (card + bank transfer) ───────────────────────────

// GET /api/payments-online/:bizId/options
// Returns available payment methods for this business (no auth — public config)
router.get('/:bizId/options', async (req, res) => {
  try {
    const [[cfg]] = await db.query(`
      SELECT bc.feature_online_payments, bc.bank_name, bc.bank_iban, bc.bank_beneficiary,
             bc.payment_methods,
             pp.is_active AS stripe_active,
             pp.config    AS stripe_config
      FROM business_configs bc
      LEFT JOIN payment_providers pp ON pp.business_id = bc.business_id AND pp.provider = 'stripe'
      WHERE bc.business_id = ?
    `, [req.params.bizId]);

    if (!cfg || !cfg.feature_online_payments) {
      return res.json({ enabled: false, methods: [] });
    }

    const methods = [];

    if (cfg.stripe_active) {
      const sc = typeof cfg.stripe_config === 'string'
        ? JSON.parse(cfg.stripe_config) : (cfg.stripe_config || {});
      methods.push({ type: 'card', publishable_key: sc.publishable_key || null });
    }

    if (cfg.bank_iban) {
      methods.push({
        type:        'bank_transfer',
        bank_name:   cfg.bank_name || null,
        iban:        cfg.bank_iban,
        beneficiary: cfg.bank_beneficiary || null,
      });
    }

    const extra = typeof cfg.payment_methods === 'string'
      ? JSON.parse(cfg.payment_methods) : (cfg.payment_methods || []);
    extra.forEach(m => { if (!methods.find(x => x.type === m.type)) methods.push(m); });

    return res.json({ enabled: true, methods });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/payments-online/:bizId/bank-transfer
// Body: { payment_id } — user declares they made a bank transfer; marks payment as pending_transfer
router.post('/:bizId/bank-transfer', softAuth, requireActiveCustomer, async (req, res) => {
  const { payment_id } = req.body;
  if (!payment_id) return res.status(400).json({ error: 'Απαιτείται payment_id' });

  try {
    const [[payment]] = await db.query(`
      SELECT id, amount_cents, paid_amount_cents, status, user_id, business_id
      FROM payments WHERE id = ? AND business_id = ? AND user_id = ?
    `, [payment_id, req.params.bizId, req.user.userId]);

    if (!payment) return res.status(404).json({ error: 'Πληρωμή δεν βρέθηκε' });
    if (payment.status === 'paid') return res.status(409).json({ error: 'Έχει ήδη πληρωθεί' });

    await db.query(
      `UPDATE payments SET method = 'bank_transfer', notes = CONCAT(COALESCE(notes,''), '\n[Δήλωση κατάθεσης: ', NOW(), ']') WHERE id = ?`,
      [payment_id],
    );

    return res.json({ ok: true, message: 'Η κατάθεση καταχωρήθηκε. Αναμένει επιβεβαίωση από το γυμναστήριο.' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PUT /api/payments-online/:bizId/bank-details
// Admin: save bank account details for bank transfer payments
router.put('/:bizId/bank-details', authenticate, async (req, res) => {
  const { bank_name, bank_iban, bank_beneficiary } = req.body;
  if (!bank_iban) return res.status(400).json({ error: 'Απαιτείται IBAN' });
  try {
    await db.query(
      'UPDATE business_configs SET bank_name = ?, bank_iban = ?, bank_beneficiary = ?, feature_online_payments = 1 WHERE business_id = ?',
      [bank_name || null, bank_iban.replace(/\s/g, ''), bank_beneficiary || null, req.params.bizId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

module.exports = router;
