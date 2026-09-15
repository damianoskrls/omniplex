'use strict';

/**
 * Provider abstraction layer.
 * Each provider module must export: createIntent, retrieveIntent, constructEvent, refundCharge.
 */

const stripeProvider = require('./providers/stripe');
const { submitReceipt, loadMydataConfig } = require('./mydata');

// ── Provider registry ────────────────────────────────────────────────────────

const PROVIDERS = {
  stripe: stripeProvider,
  // viva:    require('./providers/viva'),    // future
  // everypay: require('./providers/everypay'), // future
};

async function getProviderConfig(conn, bizId) {
  const [[row]] = await conn.query(`
    SELECT * FROM payment_providers
    WHERE business_id = ? AND is_active = 1
    LIMIT 1
  `, [bizId]);
  if (!row) throw Object.assign(new Error('Online πληρωμές δεν έχουν ρυθμιστεί'), { status: 400 });
  const cfg = typeof row.config === 'string' ? JSON.parse(row.config) : (row.config || {});
  return { provider: row.provider, ...cfg };
}

function getProviderModule(providerName) {
  const mod = PROVIDERS[providerName];
  if (!mod) throw new Error(`Άγνωστος provider: ${providerName}`);
  return mod;
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Create a payment intent for a given amount.
 * Returns { client_secret, intent_id, provider, publishable_key }
 */
async function createPaymentIntent(conn, bizId, { amountCents, currency = 'eur', metadata = {}, userId, userEmail, userName }) {
  const provCfg = await getProviderConfig(conn, bizId);
  const mod     = getProviderModule(provCfg.provider);

  let customerId;
  if (provCfg.provider === 'stripe' && userId) {
    customerId = await mod.ensureCustomer({
      secretKey: provCfg.secret_key,
      userId, email: userEmail, name: userName,
    });
  }

  const result = await mod.createIntent({
    secretKey:    provCfg.secret_key,
    amountCents,
    currency,
    metadata:     { ...metadata, business_id: bizId, user_id: userId || '' },
    customerId,
  });

  return {
    ...result,
    provider:        provCfg.provider,
    publishable_key: provCfg.publishable_key || null,
  };
}

/**
 * Confirm a payment intent is succeeded.
 * Returns { status, charge_id }
 */
async function confirmPayment(conn, bizId, intentId) {
  const provCfg = await getProviderConfig(conn, bizId);
  const mod     = getProviderModule(provCfg.provider);
  return mod.retrieveIntent({ secretKey: provCfg.secret_key, intentId });
}

/**
 * Verify and parse a webhook event.
 * Returns the raw provider event.
 */
async function parseWebhook(conn, bizId, { rawBody, signature }) {
  const provCfg = await getProviderConfig(conn, bizId);
  const mod     = getProviderModule(provCfg.provider);
  return mod.constructEvent({
    secretKey:     provCfg.secret_key,
    webhookSecret: provCfg.webhook_secret,
    rawBody,
    signature,
  });
}

/**
 * Mark a payment as paid (online) and optionally submit to myDATA.
 * Updates the existing payment row.
 */
async function markPaymentPaid(conn, bizId, paymentId, {
  providerTxnId, intentId, provider, description, seriesNumber,
}) {
  await conn.query(`
    UPDATE payments
    SET status = 'paid', paid_amount_cents = amount_cents,
        payment_date = CURDATE(),
        provider = ?, provider_txn_id = ?, provider_intent_id = ?,
        method = 'online'
    WHERE id = ? AND business_id = ?
  `, [provider, providerTxnId, intentId, paymentId, bizId]);

  // Submit to myDATA if configured
  const mydataCfg = await loadMydataConfig(conn, bizId);
  if (mydataCfg?.is_enabled) {
    const [[payment]] = await conn.query(
      'SELECT amount_cents, description FROM payments WHERE id = ?', [paymentId],
    );
    try {
      const { mark, uid } = await submitReceipt(mydataCfg, {
        grossCents:   payment.amount_cents,
        description:  description || payment.description,
        issueDate:    new Date().toISOString().slice(0, 10),
        seriesNumber: seriesNumber || paymentId.slice(0, 8).toUpperCase(),
      });
      if (mark) {
        await conn.query(`
          UPDATE payments
          SET mydata_mark = ?, mydata_uid = ?,
              mydata_invoice_type = ?, mydata_submitted_at = NOW()
          WHERE id = ?
        `, [mark, uid, mydataCfg.invoice_type || '11.1', paymentId]);
      }
    } catch (err) {
      // Log but don't fail the payment — myDATA submission can be retried
      console.error('[myDATA] markPaymentPaid:', err.message);
    }
  }
}

/**
 * Issue a refund.
 */
async function refundPayment(conn, bizId, paymentId) {
  const [[payment]] = await conn.query(
    'SELECT provider, provider_txn_id, amount_cents FROM payments WHERE id = ? AND business_id = ?',
    [paymentId, bizId],
  );
  if (!payment?.provider) throw new Error('Δεν είναι online πληρωμή');

  const provCfg = await getProviderConfig(conn, bizId);
  const mod     = getProviderModule(payment.provider);

  const { refund_id } = await mod.refundCharge({
    secretKey:   provCfg.secret_key,
    chargeId:    payment.provider_txn_id,
    amountCents: payment.amount_cents,
  });

  await conn.query(
    `UPDATE payments SET status = 'refunded' WHERE id = ? AND business_id = ?`,
    [paymentId, bizId],
  );

  return { refund_id };
}

module.exports = { createPaymentIntent, confirmPayment, parseWebhook, markPaymentPaid, refundPayment };
