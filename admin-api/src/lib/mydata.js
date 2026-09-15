'use strict';

const https = require('https');

const AADE_SANDBOX = 'mydata.aade.gr';
const AADE_LIVE    = 'mydatapi.aade.gr';

function getHost(isProduction) {
  return isProduction ? AADE_LIVE : AADE_SANDBOX;
}

/**
 * POST XML to AADE myDATA and return parsed MARK + UID.
 */
function postToAade(host, path, xml, userId, subscriptionKey) {
  return new Promise((resolve, reject) => {
    const body = Buffer.from(xml, 'utf8');
    const req = https.request({
      hostname: host,
      path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/xml',
        'Content-Length': body.length,
        'aade-user-id': userId,
        'Ocp-Apim-Subscription-Key': subscriptionKey,
      },
    }, (res) => {
      let raw = '';
      res.on('data', c => { raw += c; });
      res.on('end', () => resolve({ status: res.statusCode, body: raw }));
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

/**
 * Parse MARK and UID from AADE response XML.
 * AADE returns something like:
 *   <response><invoicesRegistrationNumber mark="..."><invoiceUid uid="..."/></invoicesRegistrationNumber></response>
 */
function parseMark(xmlBody) {
  const markMatch = xmlBody.match(/mark="([^"]+)"/i)
    || xmlBody.match(/<mark>([^<]+)<\/mark>/i);
  const uidMatch  = xmlBody.match(/uid="([^"]+)"/i)
    || xmlBody.match(/<uid>([^<]+)<\/uid>/i);
  return {
    mark: markMatch?.[1] || null,
    uid:  uidMatch?.[1]  || null,
  };
}

/**
 * Build minimal myDATA XML (invoice type 11.1 — Απόδειξη Λιανικής).
 *
 * @param {object} params
 * @param {string} params.issuerVat       - ΑΦΜ εκδότη
 * @param {string} params.issuerName      - Επωνυμία εκδότη
 * @param {string} params.issuerAddress   - Διεύθυνση εκδότη
 * @param {string} params.taxAuthority    - ΔΟΥ
 * @param {string} params.invoiceType     - '11.1'
 * @param {string} params.issueDate       - 'YYYY-MM-DD'
 * @param {string} params.seriesNumber    - e.g. 'A/1'
 * @param {number} params.netValueCents   - amount before VAT
 * @param {number} params.vatCents        - VAT amount
 * @param {number} params.vatCategory     - 1=24% 2=13% 3=6% 8=0%
 * @param {string} params.description     - line item description
 * @param {string} [params.counterpartVat] - buyer ΑΦΜ (optional for retail)
 */
function buildInvoiceXml({
  issuerVat, issuerName, issuerAddress, taxAuthority,
  invoiceType, issueDate, seriesNumber,
  netValueCents, vatCents, vatCategory,
  description, counterpartVat,
}) {
  const net = (netValueCents / 100).toFixed(2);
  const vat = (vatCents / 100).toFixed(2);
  const gross = ((netValueCents + vatCents) / 100).toFixed(2);

  const counterpartBlock = counterpartVat
    ? `<counterpart><vatNumber>${counterpartVat}</vatNumber></counterpart>`
    : '';

  // Series/number: e.g. 'A/1' → series='A', aa=1
  const parts = String(seriesNumber).split('/');
  const series = parts[0] || 'A';
  const aa = parts[1] || '1';

  return `<?xml version="1.0" encoding="UTF-8"?>
<InvoicesDoc xmlns="https://www.aade.gr/myDATA/invoice/v1.0"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="https://www.aade.gr/myDATA/invoice/v1.0/InvoiceDoc.xsd">
  <invoice>
    <issuer>
      <vatNumber>${issuerVat}</vatNumber>
      <country>GR</country>
      <branch>0</branch>
    </issuer>
    ${counterpartBlock}
    <invoiceHeader>
      <series>${series}</series>
      <aa>${aa}</aa>
      <issueDate>${issueDate}</issueDate>
      <invoiceType>${invoiceType}</invoiceType>
      <currency>EUR</currency>
    </invoiceHeader>
    <paymentMethods>
      <paymentMethodDetails>
        <type>3</type>
        <amount>${gross}</amount>
      </paymentMethodDetails>
    </paymentMethods>
    <invoiceDetails>
      <lineNumber>1</lineNumber>
      <netValue>${net}</netValue>
      <vatCategory>${vatCategory}</vatCategory>
      <vatAmount>${vat}</vatAmount>
      <discountOption>false</discountOption>
      <itemDescr>${description}</itemDescr>
    </invoiceDetails>
    <invoiceSummary>
      <totalNetValue>${net}</totalNetValue>
      <totalVatAmount>${vat}</totalVatAmount>
      <totalWithheldAmount>0.00</totalWithheldAmount>
      <totalFeesAmount>0.00</totalFeesAmount>
      <totalStampDutyAmount>0.00</totalStampDutyAmount>
      <totalOtherTaxesAmount>0.00</totalOtherTaxesAmount>
      <totalDeductionsAmount>0.00</totalDeductionsAmount>
      <totalGrossValue>${gross}</totalGrossValue>
      <incomeClassification>
        <classificationType>E3_561_001</classificationType>
        <classificationCategory>category1_1</classificationCategory>
        <amount>${net}</amount>
      </incomeClassification>
    </invoiceSummary>
  </invoice>
</InvoicesDoc>`;
}

/**
 * VAT rates by category code.
 */
const VAT_RATES = { 1: 0.24, 2: 0.13, 3: 0.06, 4: 0.17, 5: 0.09, 7: 0.04, 8: 0.00 };

/**
 * Split a gross amount into net + vat given a category.
 */
function splitVat(grossCents, vatCategory) {
  const rate = VAT_RATES[vatCategory] ?? 0.24;
  const net  = Math.round(grossCents / (1 + rate));
  const vat  = grossCents - net;
  return { net, vat };
}

/**
 * Submit a receipt to AADE myDATA.
 * Returns { mark, uid } or throws.
 */
async function submitReceipt(cfg, {
  grossCents, description, issueDate, seriesNumber, counterpartVat,
}) {
  if (!cfg.is_enabled) return { mark: null, uid: null, skipped: true };

  const { net, vat } = splitVat(grossCents, cfg.vat_category);
  const xml = buildInvoiceXml({
    issuerVat:      cfg.vat_number,
    issuerName:     cfg.legal_name,
    issuerAddress:  cfg.address,
    taxAuthority:   cfg.tax_authority,
    invoiceType:    cfg.invoice_type || '11.1',
    issueDate:      issueDate || new Date().toISOString().slice(0, 10),
    seriesNumber:   seriesNumber,
    netValueCents:  net,
    vatCents:       vat,
    vatCategory:    cfg.vat_category,
    description,
    counterpartVat,
  });

  const host = getHost(!!cfg.is_production);
  const { status, body } = await postToAade(
    host, '/myDATA/SendInvoices', xml, cfg.aade_user_id, cfg.aade_subscription_key,
  );

  if (status !== 200) {
    console.error('[myDATA] HTTP', status, body.slice(0, 300));
    throw new Error(`myDATA error ${status}: ${body.slice(0, 200)}`);
  }

  const { mark, uid } = parseMark(body);
  if (!mark) {
    console.error('[myDATA] No MARK in response:', body.slice(0, 500));
    throw new Error('myDATA: δεν επιστράφηκε MARK');
  }

  return { mark, uid };
}

/**
 * Load myDATA config for a business.
 */
async function loadMydataConfig(conn, bizId) {
  const [[row]] = await conn.query(
    'SELECT * FROM mydata_config WHERE business_id = ?', [bizId],
  );
  return row || null;
}

module.exports = { submitReceipt, loadMydataConfig, buildInvoiceXml, splitVat, VAT_RATES };
