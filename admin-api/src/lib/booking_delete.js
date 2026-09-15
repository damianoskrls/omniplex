const { notifyWaitlistOnCancel } = require('./waitlist');
const { refundBookingMembershipOnRemove } = require('./create_booking');

async function deleteBookingForBusiness(conn, bizId, bookingId) {
  const [[booking]] = await conn.query(`
    SELECT b.*, sv.name AS service_name
    FROM bookings b
    JOIN services sv ON sv.id = b.service_id
    WHERE b.id = ? AND b.business_id = ?
  `, [bookingId, bizId]);
  if (!booking) return null;

  if (!['cancelled', 'no_show'].includes(booking.status)) {
    await notifyWaitlistOnCancel(
      conn, bizId, booking.service_id, booking.starts_at, booking.service_name,
    );
  }

  await refundBookingMembershipOnRemove(conn, booking);

  await conn.query(
    'UPDATE user_memberships SET trial_booking_id = NULL WHERE trial_booking_id = ?',
    [bookingId],
  );

  await conn.query('DELETE FROM bookings WHERE id = ? AND business_id = ?', [bookingId, bizId]);
  return booking;
}

module.exports = { deleteBookingForBusiness };
