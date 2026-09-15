'use strict';

const Stripe = require('stripe');

function getStripe(secretKey) {
  return Stripe(secretKey, { apiVersion: '2024-12-18.acacia' });
}

/**
 * Create a PaymentIntent.
 * Returns { client_secret, intent_id }
 */
async function createIntent({ secretKey, amountCents, currency = 'eur', metadata = {}, customerId }) {
  const stripe = getStripe(secretKey);
  const intent = await stripe.paymentIntents.create({
    amount: amountCents,
    currency,
    metadata,
    ...(customerId ? { customer: customerId } : {}),
    automatic_payment_methods: { enabled: true },
  });
  return { client_secret: intent.client_secret, intent_id: intent.id };
}

/**
 * Retrieve intent status.
 * Returns { status, charge_id, amount }
 */
async function retrieveIntent({ secretKey, intentId }) {
  const stripe = getStripe(secretKey);
  const intent = await stripe.paymentIntents.retrieve(intentId);
  const chargeId = intent.latest_charge || null;
  return {
    status: intent.status,           // 'succeeded' | 'requires_payment_method' | ...
    charge_id: chargeId,
    amount: intent.amount,
  };
}

/**
 * Verify a Stripe webhook event signature.
 * Returns the parsed event or throws.
 */
function constructEvent({ secretKey, webhookSecret, rawBody, signature }) {
  const stripe = getStripe(secretKey);
  return stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
}

/**
 * Create or retrieve a Stripe Customer for a user.
 */
async function ensureCustomer({ secretKey, userId, email, name }) {
  const stripe = getStripe(secretKey);
  const existing = await stripe.customers.search({
    query: `metadata['user_id']:'${userId}'`,
    limit: 1,
  });
  if (existing.data.length) return existing.data[0].id;
  const customer = await stripe.customers.create({
    email: email || undefined,
    name: name || undefined,
    metadata: { user_id: userId },
  });
  return customer.id;
}

/**
 * Issue a full refund for a charge.
 */
async function refundCharge({ secretKey, chargeId, amountCents }) {
  const stripe = getStripe(secretKey);
  const refund = await stripe.refunds.create({
    charge: chargeId,
    ...(amountCents ? { amount: amountCents } : {}),
  });
  return { refund_id: refund.id, status: refund.status };
}

module.exports = { createIntent, retrieveIntent, constructEvent, ensureCustomer, refundCharge };
