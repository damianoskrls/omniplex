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
function paymentsNotConfigured() {
  const err = new Error('Οι online πληρωμές δεν είναι ρυθμισμένες για αυτό το γυμναστήριο');
  err.status = 400;
  return err;
}

function assertStripeKeys(cfg) {
  const secret = String(cfg?.secret_key || '').trim();
  const pub = String(cfg?.publishable_key || '').trim();
  if (!/^sk_(test|live)_/.test(secret) || !/^pk_(test|live)_/.test(pub)) {
    throw paymentsNotConfigured();
  }
}

function hideStripeKeyError(err) {
  const msg = String(err?.message || '');
  if (/api key/i.test(msg) || err?.type === 'StripeAuthenticationError') {
    return paymentsNotConfigured();
  }
  return err;
}

async function createPaymentIntent(conn, bizId, { amountCents, currency = 'eur', metadata = {}, userId, userEmail, userName }) {
  const provCfg = await getProviderConfig(conn, bizId);
  const mod     = getProviderModule(provCfg.provider);
  if (provCfg.provider === 'stripe') assertStripeKeys(provCfg);

  let customerId;
  let result;
  try {
    if (provCfg.provider === 'stripe' && userId) {
      customerId = await mod.ensureCustomer({
        secretKey: provCfg.secret_key,
        userId, email: userEmail, name: userName,
      });
    }

    result = await mod.createIntent({
      secretKey:    provCfg.secret_key,
      amountCents,
      currency,
      metadata:     { ...metadata, business_id: bizId, user_id: userId || '' },
      customerId,
    });
  } catch (err) {
    throw hideStripeKeyError(err);
  }

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
  if (provCfg.provider === 'stripe') assertStripeKeys(provCfg);
  try {
    return await mod.retrieveIntent({ secretKey: provCfg.secret_key, intentId });
  } catch (err) {
    throw hideStripeKeyError(err);
  }
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

  try {
    const { settleAdvanceBookings } = require('./membership_lifecycle');
    await settleAdvanceBookings(conn, bizId, paymentId);
  } catch (err) {
    console.warn('advance sessions not applied:', err.message);
  }
}

/**
 * Issue a refund.
 */
async function refundIntent(conn, bizId, intentId, amountCents) {
  const provCfg = await getProviderConfig(conn, bizId);
  const mod = getProviderModule(provCfg.provider);
  if (provCfg.provider === 'stripe') assertStripeKeys(provCfg);
  const intent = await mod.retrieveIntent({ secretKey: provCfg.secret_key, intentId });
  if (!intent.charge_id) throw new Error('Δεν βρέθηκε χρέωση για επιστροφή');
  return mod.refundCharge({
    secretKey: provCfg.secret_key,
    chargeId: intent.charge_id,
    amountCents: amountCents || intent.amount,
  });
}

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

module.exports = {
  createPaymentIntent,
  confirmPayment,
  parseWebhook,
  markPaymentPaid,
  refundPayment,
  refundIntent,
  assertStripeKeys,
  hideStripeKeyError,
  paymentsNotConfigured,
};
