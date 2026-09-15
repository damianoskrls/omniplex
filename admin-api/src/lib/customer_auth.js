const db = require('../db');

const STATUS_MESSAGES = {
  pending: 'Ο λογαριασμός σου περιμένει έγκριση από το γυμναστήριο.',
  suspended: 'Ο λογαριασμός σου είναι απενεργοποιημένος. Επικοινώνησε με το γυμναστήριο.',
  deleted: 'Ο λογαριασμός σου δεν είναι πλέον ενεργός. Επικοινώνησε με το γυμναστήριο.',
};

async function getCustomerStatus(userId) {
  const [[row]] = await db.query(
    'SELECT account_status, deleted_at FROM users WHERE id = ?',
    [userId]
  );
  if (!row) return null;
  if (row.deleted_at) return 'deleted';
  return row.account_status || null;
}

async function requireActiveCustomer(req, res, next) {
  if (!req.user?.userId) {
    return res.status(401).json({ error: 'Απαιτείται σύνδεση' });
  }
  try {
    const status = await getCustomerStatus(req.user.userId);
    if (!status) {
      return res.status(401).json({ error: 'Ο χρήστης δεν βρέθηκε' });
    }
    if (status !== 'active') {
      return res.status(403).json({
        error: STATUS_MESSAGES[status] || 'Ο λογαριασμός δεν είναι ενεργός',
        code: status === 'pending' ? 'ACCOUNT_PENDING'
          : status === 'deleted' ? 'ACCOUNT_DELETED'
            : 'ACCOUNT_SUSPENDED',
        account_status: status,
      });
    }
    next();
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
}

module.exports = {
  STATUS_MESSAGES,
  getCustomerStatus,
  requireActiveCustomer,
};
