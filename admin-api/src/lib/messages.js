const { v4: uuidv4 } = require('uuid');
const { createAdminNotification } = require('./notifications');
const { validateAttachmentUrl } = require('./message_upload');
const { assertImageUploadAllowed } = require('./message_attachments');
const { sendFcm, getUserFcmTokens } = require('./push');

function buildMessagePreview({ body, message_type: messageType, attachment_url: attachmentUrl }) {
  if (messageType === 'image') {
    const cap = (body || '').trim();
    if (cap) return cap.length > 200 ? `📷 ${cap.slice(0, 196)}...` : `📷 ${cap}`;
    return '📷 Φωτογραφία';
  }
  const text = (body || '').trim();
  if (!text) return '';
  return text.length > 200 ? `${text.slice(0, 197)}...` : text;
}

function mapMessageRow(m, { viewerRole, viewerId } = {}) {
  const isMine = (
    (viewerRole === 'client' && m.sender_role === 'client')
    || (viewerRole === 'client_admin' && m.sender_role === 'admin')
    || (viewerRole === 'trainer' && m.sender_role === 'trainer' && m.sender_staff_id === viewerId)
    || (viewerRole === 'nutritionist' && m.sender_role === 'nutritionist' && m.sender_nutritionist_id === viewerId)
  );
  return {
    id: m.id,
    thread_id: m.thread_id,
    sender_role: mapSenderRoleForViewer(m.sender_role, viewerRole),
    sender_name: m.sender_name,
    body: m.body,
    message_type: m.message_type || 'text',
    attachment_url: m.attachment_url || null,
    created_at: m.created_at,
    is_mine: isMine,
  };
}

const TRAINER_CLIENT_EXISTS_SQL = `
  EXISTS (
    SELECT 1 FROM bookings b
    WHERE b.user_id = t.client_user_id AND b.business_id = t.business_id
      AND b.staff_id = ? AND b.status IN ('confirmed', 'completed')
  )
`;

const NUTRITION_CLIENT_EXISTS_SQL = `
  EXISTS (
    SELECT 1 FROM user_memberships m
    WHERE m.user_id = t.client_user_id AND m.business_id = t.business_id
      AND (
        m.service_category IN ('nutrition', 'nutrition_consultation')
        OR EXISTS (
          SELECT 1 FROM business_plans p
          WHERE p.id = m.plan_id AND p.plan_type = 'nutrition'
        )
      )
      AND COALESCE(m.membership_status, 'active') NOT IN ('trial', 'cancelled')
      AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())
  )
`;

const NUTRITION_MEMBERSHIP_JOIN_SQL = `
  INNER JOIN user_memberships m ON m.user_id = u.id AND m.business_id = u.business_id
  LEFT JOIN business_plans p ON p.id = m.plan_id
`;

const NUTRITION_MEMBERSHIP_WHERE_SQL = `
  (
    m.service_category IN ('nutrition', 'nutrition_consultation')
    OR p.plan_type = 'nutrition'
  )
  AND COALESCE(m.membership_status, 'active') NOT IN ('trial', 'cancelled')
  AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())
`;

function safeLimit(limit, max = 100) {
  return Math.min(Math.max(Number(limit) || 30, 1), max);
}

const ADMIN_EXCLUDE_NUTRITION_ONLY_SQL = `
  AND NOT (
    EXISTS (
      SELECT 1 FROM user_memberships m
      WHERE m.user_id = t.client_user_id AND m.business_id = t.business_id
        AND m.service_category = 'nutrition'
        AND m.membership_status NOT IN ('trial', 'cancelled')
    )
    AND NOT EXISTS (
      SELECT 1 FROM user_memberships m2
      WHERE m2.user_id = t.client_user_id AND m2.business_id = t.business_id
        AND (m2.service_category IS NULL OR m2.service_category != 'nutrition')
        AND m2.membership_status NOT IN ('trial', 'cancelled')
    )
    AND NOT EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.user_id = t.client_user_id AND b.business_id = t.business_id
        AND b.status IN ('confirmed', 'completed')
    )
  )
`;

function buildPeerKey(peer) {
  if (peer.peer_role === 'admin') return 'admin';
  if (peer.peer_role === 'trainer') return `trainer:${peer.peer_staff_id}`;
  if (peer.peer_role === 'nutritionist') return `nutritionist:${peer.peer_nutritionist_id}`;
  throw new Error('Invalid peer');
}

function messageBelongsToThread(m, thread) {
  if (!thread) return false;
  if (thread.peer_role === 'admin') {
    return m.sender_role === 'admin' || m.sender_role === 'client';
  }
  if (thread.peer_role === 'trainer') {
    if (m.sender_role === 'client') return true;
    return m.sender_role === 'trainer' && m.sender_staff_id === thread.peer_staff_id;
  }
  if (thread.peer_role === 'nutritionist') {
    if (m.sender_role === 'client') return true;
    return m.sender_role === 'nutritionist' && m.sender_nutritionist_id === thread.peer_nutritionist_id;
  }
  return false;
}

async function refreshThreadMetadata(conn, threadId) {
  const [last] = await conn.execute(
    `SELECT body, created_at FROM messages WHERE thread_id = ? ORDER BY created_at DESC LIMIT 1`,
    [threadId]
  );
  const preview = last[0]?.body
    ? (last[0].body.length > 200 ? `${last[0].body.slice(0, 197)}...` : last[0].body)
    : null;
  await conn.execute(
    `UPDATE message_threads
     SET last_message_at = COALESCE(?, created_at),
         last_message_preview = ?
     WHERE id = ?`,
    [last[0]?.created_at || null, preview, threadId]
  );
}

function peerFromActor(actor) {
  if (actor.role === 'client_admin') {
    return { peer_role: 'admin', peer_staff_id: null, peer_nutritionist_id: null };
  }
  if (actor.role === 'trainer') {
    if (!actor.staffId) throw Object.assign(new Error('Λείπει staff id'), { status: 403 });
    return { peer_role: 'trainer', peer_staff_id: actor.staffId, peer_nutritionist_id: null };
  }
  if (actor.role === 'nutritionist') {
    if (!actor.nutritionistId) throw Object.assign(new Error('Λείπει nutritionist id'), { status: 403 });
    return { peer_role: 'nutritionist', peer_staff_id: null, peer_nutritionist_id: actor.nutritionistId };
  }
  throw Object.assign(new Error('Μη έγκυρος ρόλος'), { status: 403 });
}

function parsePeerFromBody(body) {
  const peerRole = body?.peer_role;
  if (!peerRole || !['admin', 'trainer', 'nutritionist'].includes(peerRole)) {
    throw Object.assign(new Error('Απαιτείται peer_role (admin, trainer, nutritionist)'), { status: 400 });
  }
  if (peerRole === 'admin') {
    return { peer_role: 'admin', peer_staff_id: null, peer_nutritionist_id: null };
  }
  if (peerRole === 'trainer') {
    const staffId = body.peer_staff_id;
    if (!staffId) throw Object.assign(new Error('Απαιτείται peer_staff_id'), { status: 400 });
    return { peer_role: 'trainer', peer_staff_id: staffId, peer_nutritionist_id: null };
  }
  const nutritionistId = body.peer_nutritionist_id;
  if (!nutritionistId) throw Object.assign(new Error('Απαιτείται peer_nutritionist_id'), { status: 400 });
  return { peer_role: 'nutritionist', peer_staff_id: null, peer_nutritionist_id: nutritionistId };
}

function peerSqlForActor(actor) {
  if (actor.role === 'client_admin') {
    return { sql: `t.peer_role = 'admin'`, params: [] };
  }
  if (actor.role === 'trainer') {
    return { sql: `t.peer_role = 'trainer' AND t.peer_staff_id = ?`, params: [actor.staffId] };
  }
  if (actor.role === 'nutritionist') {
    return { sql: `t.peer_role = 'nutritionist' AND t.peer_nutritionist_id = ?`, params: [actor.nutritionistId] };
  }
  return { sql: '1=0', params: [] };
}

function threadBelongsToActor(thread, actor) {
  if (!thread) return false;
  if (actor.role === 'client_admin') return thread.peer_role === 'admin';
  if (actor.role === 'trainer') {
    return thread.peer_role === 'trainer' && thread.peer_staff_id === actor.staffId;
  }
  if (actor.role === 'nutritionist') {
    return thread.peer_role === 'nutritionist' && thread.peer_nutritionist_id === actor.nutritionistId;
  }
  return false;
}

async function getUserDisplay(conn, userId) {
  const [rows] = await conn.execute(
  `SELECT id, full_name, email, phone FROM users WHERE id = ? LIMIT 1`,
    [userId]
  );
  const u = rows[0];
  if (!u) return null;
  const name = (u.full_name || '').trim() || u.email || 'Πελάτης';
  return { ...u, name };
}

async function getBusinessName(conn, bizId) {
  const [rows] = await conn.execute(
    `SELECT name FROM businesses WHERE id = ? LIMIT 1`,
    [bizId]
  );
  return rows[0]?.name || 'Διαχείριση';
}

async function getStaffDisplay(conn, staffId) {
  const [rows] = await conn.execute(
    `SELECT id, full_name, portal_email AS email FROM staff WHERE id = ? LIMIT 1`,
    [staffId]
  );
  const s = rows[0];
  if (!s) return null;
  const name = (s.full_name || '').trim() || 'Γυμναστής';
  return { id: s.id, name, email: s.email };
}

async function getNutritionistDisplay(conn, nutritionistId) {
  const [rows] = await conn.execute(
    `SELECT id, full_name, email FROM nutritionists WHERE id = ? LIMIT 1`,
    [nutritionistId]
  );
  const n = rows[0];
  if (!n) return null;
  const name = (n.full_name || '').trim() || 'Διατροφολόγος';
  return { id: n.id, name, email: n.email };
}

async function resolveThreadPeerLabel(conn, bizId, thread) {
  if (thread.peer_role === 'admin') {
    return await getBusinessName(conn, bizId);
  }
  if (thread.peer_role === 'trainer' && thread.peer_staff_id) {
    const s = await getStaffDisplay(conn, thread.peer_staff_id);
    return s?.name || 'Γυμναστής';
  }
  if (thread.peer_role === 'nutritionist' && thread.peer_nutritionist_id) {
    const n = await getNutritionistDisplay(conn, thread.peer_nutritionist_id);
    return n?.name || 'Διατροφολόγος';
  }
  return 'Συνομιλία';
}

async function getOrCreateThread(conn, bizId, clientUserId, peer) {
  const peerKey = buildPeerKey(peer);
  const [existing] = await conn.execute(
    `SELECT id FROM message_threads
     WHERE business_id = ? AND client_user_id = ? AND peer_key = ? LIMIT 1`,
    [bizId, clientUserId, peerKey]
  );
  if (existing[0]) return existing[0];

  const id = uuidv4();
  await conn.execute(
    `INSERT INTO message_threads
       (id, business_id, client_user_id, peer_role, peer_staff_id, peer_nutritionist_id, peer_key)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      bizId,
      clientUserId,
      peer.peer_role,
      peer.peer_staff_id,
      peer.peer_nutritionist_id,
      peerKey,
    ]
  );
  return { id };
}

function mapSenderRoleForViewer(senderRole, viewerRole) {
  if (viewerRole === 'client') return senderRole;
  if (viewerRole === 'client_admin') {
    if (senderRole === 'admin') return 'admin';
    if (senderRole === 'client') return 'client';
    return senderRole;
  }
  if (viewerRole === 'trainer') {
    if (senderRole === 'trainer') return 'trainer';
    if (senderRole === 'client') return 'client';
    return senderRole;
  }
  if (viewerRole === 'nutritionist') {
    if (senderRole === 'nutritionist') return 'nutritionist';
    if (senderRole === 'client') return 'client';
    return senderRole;
  }
  return senderRole;
}

async function getThreadMessages(conn, threadId, { viewerRole, viewerId } = {}) {
  const [threadRows] = await conn.execute(
    `SELECT peer_role, peer_staff_id, peer_nutritionist_id
     FROM message_threads WHERE id = ? LIMIT 1`,
    [threadId]
  );
  const thread = threadRows[0];

  const [rows] = await conn.execute(
    `SELECT id, thread_id, sender_role, sender_client_user_id, sender_staff_id,
            sender_nutritionist_id, sender_name, body, message_type, attachment_url, created_at
     FROM messages WHERE thread_id = ? ORDER BY created_at ASC`,
    [threadId]
  );
  return rows
    .filter((m) => messageBelongsToThread(m, thread))
    .map((m) => mapMessageRow(m, { viewerRole, viewerId }));
}

async function formatThreadRow(conn, row, { unreadField }) {
  const client = await getUserDisplay(conn, row.client_user_id);
  const peerLabel = await resolveThreadPeerLabel(conn, row.business_id, row);
  const lastSeen = row.last_seen_at ? new Date(row.last_seen_at) : null;
  const isOnline = lastSeen && (Date.now() - lastSeen.getTime()) < 5 * 60 * 1000;
  return {
    id: row.id,
    business_id: row.business_id,
    client_user_id: row.client_user_id,
    client_name: client?.name || 'Πελάτης',
    client_email: client?.email || null,
    client_phone: client?.phone || null,
    peer_role: row.peer_role,
    peer_staff_id: row.peer_staff_id,
    peer_nutritionist_id: row.peer_nutritionist_id,
    peer_name: peerLabel,
    subject: row.subject,
    last_message_at: row.last_message_at,
    last_message_preview: row.last_message_preview,
    unread_count: row[unreadField] || 0,
    created_at: row.created_at,
    last_seen_at: row.last_seen_at || null,
    is_online: !!isOnline,
  };
}

function peerSubtitle(peerRole) {
  if (peerRole === 'admin') return 'Διαχείριση γυμναστηρίου';
  if (peerRole === 'trainer') return 'Γυμναστής';
  if (peerRole === 'nutritionist') return 'Διατροφολόγος';
  return '';
}

async function formatClientThreadRow(conn, row) {
  const peerLabel = await resolveThreadPeerLabel(conn, row.business_id, row);
  return {
    id: row.id,
    peer_role: row.peer_role,
    peer_staff_id: row.peer_staff_id,
    peer_nutritionist_id: row.peer_nutritionist_id,
    peer_name: peerLabel,
    peer_subtitle: peerSubtitle(row.peer_role),
    last_message_at: row.last_message_at,
    last_message_preview: row.last_message_preview,
    unread_count: row.client_unread_count || 0,
  };
}

async function canStaffAccessClient(conn, actor, clientUserId) {
  if (actor.role === 'client_admin') {
    const [rows] = await conn.execute(
      `SELECT u.id, u.full_name, u.email, u.phone
       FROM users u
       WHERE u.id = ? AND u.business_id = ?
         AND (u.account_status IS NULL OR u.account_status = 'active')
         AND (u.deleted_at IS NULL)`,
      [clientUserId, actor.businessId]
    );
    if (!rows[0]) return null;
    const [nutOnly] = await conn.execute(
      `SELECT 1 FROM user_memberships m
       WHERE m.user_id = ? AND m.business_id = ?
         AND m.service_category = 'nutrition'
         AND m.membership_status NOT IN ('trial', 'cancelled')
       AND NOT EXISTS (
         SELECT 1 FROM user_memberships m2
         WHERE m2.user_id = ? AND m2.business_id = ?
           AND (m2.service_category IS NULL OR m2.service_category != 'nutrition')
           AND m2.membership_status NOT IN ('trial', 'cancelled')
       )
       AND NOT EXISTS (
         SELECT 1 FROM bookings b
         WHERE b.user_id = ? AND b.business_id = ?
           AND b.status IN ('confirmed', 'completed')
       ) LIMIT 1`,
      [clientUserId, actor.businessId, clientUserId, actor.businessId, clientUserId, actor.businessId]
    );
    if (nutOnly.length) return null;
    const name = (rows[0].full_name || '').trim() || rows[0].email;
    return { ...rows[0], name };
  }

  if (actor.role === 'trainer') {
    const [rows] = await conn.execute(
      `SELECT DISTINCT u.id, u.full_name, u.email, u.phone
       FROM users u
       INNER JOIN bookings b ON b.user_id = u.id AND b.business_id = ?
       WHERE u.id = ? AND b.staff_id = ?
         AND b.status IN ('confirmed', 'completed')
         AND (u.account_status IS NULL OR u.account_status = 'active') AND (u.deleted_at IS NULL)
       LIMIT 1`,
      [actor.businessId, clientUserId, actor.staffId]
    );
    if (!rows[0]) return null;
    const name = (rows[0].full_name || '').trim() || rows[0].email;
    return { ...rows[0], name };
  }

  if (actor.role === 'nutritionist') {
    const [rows] = await conn.execute(
      `SELECT DISTINCT u.id, u.full_name, u.email, u.phone
       FROM users u
       ${NUTRITION_MEMBERSHIP_JOIN_SQL}
       WHERE u.id = ? AND u.business_id = ?
         AND ${NUTRITION_MEMBERSHIP_WHERE_SQL}
         AND COALESCE(u.account_status, 'active') = 'active' AND (u.deleted_at IS NULL)
       LIMIT 1`,
      [clientUserId, actor.businessId]
    );
    if (!rows[0]) return null;
    const name = (rows[0].full_name || '').trim() || rows[0].email;
    return { ...rows[0], name };
  }

  return null;
}

async function listStaffThreads(dbOrConn, actor, { q = '', limit = 50 } = {}) {
  const conn = dbOrConn;
  const peerFilter = peerSqlForActor(actor);
  let extraFilter = '';
  const params = [actor.businessId, ...peerFilter.params];

  if (actor.role === 'trainer') {
    extraFilter = `AND ${TRAINER_CLIENT_EXISTS_SQL}`;
    params.push(actor.staffId);
  } else if (actor.role === 'nutritionist') {
    extraFilter = `AND ${NUTRITION_CLIENT_EXISTS_SQL}`;
  } else if (actor.role === 'client_admin') {
    extraFilter = ADMIN_EXCLUDE_NUTRITION_ONLY_SQL;
  }

  let searchSql = '';
  if (q && q.trim()) {
    searchSql = `AND (u.full_name LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)`;
    const like = `%${q.trim()}%`;
    params.push(like, like, like);
  }

  const safeLimit = Math.min(Math.max(limit, 1), 100);

  const [rows] = await conn.execute(
    `SELECT t.*, u.full_name, u.email, u.phone, u.last_seen_at
     FROM message_threads t
     INNER JOIN users u ON u.id = t.client_user_id
     WHERE t.business_id = ?
       AND ${peerFilter.sql}
       ${extraFilter}
       ${searchSql}
     ORDER BY t.last_message_at DESC
     LIMIT ${safeLimit}`,
    params
  );

  const out = [];
  for (const row of rows) {
    out.push(await formatThreadRow(conn, row, { unreadField: 'staff_unread_count' }));
  }
  return out;
}

async function listStaffContacts(dbOrConn, actor, { q = '', limit = 30 } = {}) {
  const conn = dbOrConn;
  const like = q?.trim() ? `%${q.trim()}%` : null;
  const lim = safeLimit(limit, 100);

  if (actor.role === 'trainer') {
    const params = [actor.businessId, actor.staffId];
    let search = '';
    if (like) {
      search = 'AND (u.full_name LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)';
      params.push(like, like, like);
    }
    const [rows] = await conn.execute(
      `SELECT DISTINCT u.id AS client_user_id, u.full_name, u.email, u.phone
       FROM users u
       INNER JOIN bookings b ON b.user_id = u.id AND b.business_id = ?
       WHERE b.staff_id = ? AND b.status IN ('confirmed', 'completed')
         AND COALESCE(u.account_status, 'active') = 'active' AND (u.deleted_at IS NULL)
         ${search}
       ORDER BY u.full_name
       LIMIT ${lim}`,
      params
    );
    return rows.map((r) => ({
      client_user_id: r.client_user_id,
      client_name: (r.full_name || '').trim() || r.email,
      client_email: r.email,
      client_phone: r.phone,
    }));
  }

  if (actor.role === 'nutritionist') {
    const params = [actor.businessId];
    let search = '';
    if (like) {
      search = 'AND (u.full_name LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)';
      params.push(like, like, like);
    }
    const [rows] = await conn.execute(
      `SELECT DISTINCT u.id AS client_user_id, u.full_name, u.email, u.phone
       FROM users u
       ${NUTRITION_MEMBERSHIP_JOIN_SQL}
       WHERE u.business_id = ?
         AND ${NUTRITION_MEMBERSHIP_WHERE_SQL}
         AND COALESCE(u.account_status, 'active') = 'active' AND (u.deleted_at IS NULL)
         ${search}
       ORDER BY u.full_name
       LIMIT ${lim}`,
      params
    );
    return rows.map((r) => ({
      client_user_id: r.client_user_id,
      client_name: (r.full_name || '').trim() || r.email,
      client_email: r.email,
      client_phone: r.phone,
    }));
  }

  const params = [actor.businessId];
  let search = '';
  if (like) {
    search = 'AND (u.full_name LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)';
    params.push(like, like, like);
  }
  params.push(actor.businessId, actor.businessId, actor.businessId);
  const [rows] = await conn.execute(
    `SELECT u.id AS client_user_id, u.full_name, u.email, u.phone
     FROM users u
     WHERE u.business_id = ?
       AND COALESCE(u.account_status, 'active') = 'active' AND (u.deleted_at IS NULL)
       ${search}
       AND NOT (
         EXISTS (
           SELECT 1 FROM user_memberships m
           WHERE m.user_id = u.id AND m.business_id = ?
             AND (
               m.service_category IN ('nutrition', 'nutrition_consultation')
               OR EXISTS (
                 SELECT 1 FROM business_plans p
                 WHERE p.id = m.plan_id AND p.plan_type = 'nutrition'
               )
             )
             AND COALESCE(m.membership_status, 'active') NOT IN ('trial', 'cancelled')
         )
         AND NOT EXISTS (
           SELECT 1 FROM user_memberships m2
           WHERE m2.user_id = u.id AND m2.business_id = ?
             AND (m2.service_category IS NULL OR m2.service_category NOT IN ('nutrition', 'nutrition_consultation'))
             AND COALESCE(m2.membership_status, 'active') NOT IN ('trial', 'cancelled')
         )
         AND NOT EXISTS (
           SELECT 1 FROM bookings b
           WHERE b.user_id = u.id AND b.business_id = ?
             AND b.status IN ('confirmed', 'completed')
         )
       )
     ORDER BY u.full_name
     LIMIT ${lim}`,
    params
  );
  return rows.map((r) => ({
    client_user_id: r.client_user_id,
    client_name: (r.full_name || '').trim() || r.email,
    client_email: r.email,
    client_phone: r.phone,
  }));
}

async function getThreadForStaff(dbOrConn, actor, threadId) {
  const conn = dbOrConn;
  const [rows] = await conn.execute(
    `SELECT t.*, u.full_name, u.email, u.phone
     FROM message_threads t
     INNER JOIN users u ON u.id = t.client_user_id
     WHERE t.id = ? AND t.business_id = ? LIMIT 1`,
    [threadId, actor.businessId]
  );
  const row = rows[0];
  if (!row || !threadBelongsToActor(row, actor)) return null;

  const client = await canStaffAccessClient(conn, actor, row.client_user_id);
  if (!client) return null;

  return formatThreadRow(conn, row, { unreadField: 'staff_unread_count' });
}

async function getStaffUnreadCount(dbOrConn, actor) {
  const conn = dbOrConn;
  const peerFilter = peerSqlForActor(actor);
  let extraFilter = '';
  const params = [actor.businessId, ...peerFilter.params];

  if (actor.role === 'trainer') {
    extraFilter = `AND ${TRAINER_CLIENT_EXISTS_SQL}`;
    params.push(actor.staffId);
  } else if (actor.role === 'nutritionist') {
    extraFilter = `AND ${NUTRITION_CLIENT_EXISTS_SQL}`;
  } else if (actor.role === 'client_admin') {
    extraFilter = ADMIN_EXCLUDE_NUTRITION_ONLY_SQL;
  }

  const [rows] = await conn.execute(
    `SELECT COALESCE(SUM(t.staff_unread_count), 0) AS total
     FROM message_threads t
     WHERE t.business_id = ? AND ${peerFilter.sql} ${extraFilter}`,
    params
  );
  return Number(rows[0]?.total || 0);
}

async function markStaffThreadRead(dbOrConn, actor, threadId) {
  const conn = dbOrConn;
  const thread = await getThreadForStaff(conn, actor, threadId);
  if (!thread) throw Object.assign(new Error('Η συνομιλία δεν βρέθηκε'), { status: 404 });

  await conn.execute(
    `UPDATE message_threads SET staff_unread_count = 0 WHERE id = ?`,
    [threadId]
  );
  return { ok: true };
}

async function resolveStaffSender(conn, actor) {
  if (actor.role === 'client_admin') {
    const bizName = await getBusinessName(conn, actor.businessId);
    return { sender_role: 'admin', sender_staff_id: null, sender_nutritionist_id: null, sender_name: bizName };
  }
  if (actor.role === 'trainer') {
    const staff = await getStaffDisplay(conn, actor.staffId);
    return {
      sender_role: 'trainer',
      sender_staff_id: actor.staffId,
      sender_nutritionist_id: null,
      sender_name: staff?.name || 'Γυμναστής',
    };
  }
  const nut = await getNutritionistDisplay(conn, actor.nutritionistId);
  return {
    sender_role: 'nutritionist',
    sender_staff_id: null,
    sender_nutritionist_id: actor.nutritionistId,
    sender_name: nut?.name || 'Διατροφολόγος',
  };
}

async function sendStaffMessage(conn, actor, { threadId, body, attachment_url: attachmentUrl, message_type: messageType }) {
  const text = (body || '').trim();
  const type = messageType || (attachmentUrl ? 'image' : 'text');
  if (!text && !attachmentUrl) throw Object.assign(new Error('Κενό μήνυμα'), { status: 400 });
  if (type === 'image' && !attachmentUrl) {
    throw Object.assign(new Error('Απαιτείται εικόνα'), { status: 400 });
  }

  const thread = await getThreadForStaff(conn, actor, threadId);
  if (!thread) throw Object.assign(new Error('Η συνομιλία δεν βρέθηκε'), { status: 404 });

  if (type === 'image') {
    const sender = await resolveStaffSender(conn, actor);
    await assertImageUploadAllowed(conn, {
      businessId: actor.businessId,
      senderRole: sender.sender_role,
      senderStaffId: sender.sender_staff_id,
      senderNutritionistId: sender.sender_nutritionist_id,
    });
  }

  const safeAttachment = validateAttachmentUrl(actor.businessId, threadId, attachmentUrl);
  const sender = await resolveStaffSender(conn, actor);
  const msgId = uuidv4();
  const preview = buildMessagePreview({ body: text, message_type: type, attachment_url: safeAttachment });

  await conn.execute(
    `INSERT INTO messages
       (id, thread_id, business_id, sender_role, sender_staff_id, sender_nutritionist_id, sender_name, body, message_type, attachment_url)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      msgId,
      threadId,
      actor.businessId,
      sender.sender_role,
      sender.sender_staff_id,
      sender.sender_nutritionist_id,
      sender.sender_name,
      text,
      type,
      safeAttachment,
    ]
  );

  await conn.execute(
    `UPDATE message_threads
     SET last_message_at = NOW(), last_message_preview = ?, client_unread_count = client_unread_count + 1
     WHERE id = ?`,
    [preview, threadId]
  );

  const message = {
    id: msgId,
    thread_id: threadId,
    sender_role: sender.sender_role,
    sender_name: sender.sender_name,
    body: text,
    message_type: type,
    attachment_url: safeAttachment,
    created_at: new Date(),
    is_mine: true,
  };

  // FCM push to the client (fire-and-forget)
  try {
    const tokens = await getUserFcmTokens(conn, thread.client_user_id);
    if (tokens.length > 0) {
      const preview = type === 'image' ? '📷 Φωτογραφία' : (text.length > 100 ? text.slice(0, 100) + '…' : text);
      await sendFcm(tokens, {
        title: sender.sender_name,
        body: preview,
        data: { type: 'message', thread_id: threadId },
      });
    }
  } catch (_) {}

  return { message, thread_id: threadId };
}

async function validateClientCanMessagePeer(conn, bizId, userId, peer) {
  const [userRows] = await conn.execute(
    `SELECT id FROM users WHERE id = ? AND business_id = ?
       AND COALESCE(account_status, 'active') = 'active' AND (deleted_at IS NULL) LIMIT 1`,
    [userId, bizId]
  );
  if (!userRows[0]) return false;

  if (peer.peer_role === 'admin') return true;

  if (peer.peer_role === 'trainer') {
    const [rows] = await conn.execute(
      `SELECT 1 FROM bookings b
       WHERE b.user_id = ? AND b.business_id = ? AND b.staff_id = ?
         AND b.status IN ('confirmed', 'completed') LIMIT 1`,
      [userId, bizId, peer.peer_staff_id]
    );
    return rows.length > 0;
  }

  const [rows] = await conn.execute(
    `SELECT 1 FROM user_memberships m
     WHERE m.user_id = ? AND m.business_id = ?
       AND m.service_category = 'nutrition'
       AND m.membership_status NOT IN ('trial', 'cancelled') LIMIT 1`,
    [userId, bizId]
  );
  if (!rows.length) return false;

  const [nutRows] = await conn.execute(
    `SELECT id FROM nutritionists WHERE id = ? AND business_id = ? LIMIT 1`,
    [peer.peer_nutritionist_id, bizId]
  );
  return nutRows.length > 0;
}

async function getNutritionistStaffIds(conn, bizId) {
  const [rows] = await conn.execute(
    `SELECT staff_id FROM nutritionists
     WHERE business_id = ? AND staff_id IS NOT NULL AND is_active = 1`,
    [bizId]
  );
  return new Set(rows.map((r) => r.staff_id).filter(Boolean));
}

async function listClientPeers(dbOrConn, bizId, userId) {
  const conn = dbOrConn;
  const peers = [];
  const nutritionistStaffIds = await getNutritionistStaffIds(conn, bizId);

  const bizName = await getBusinessName(conn, bizId);
  peers.push({
    peer_role: 'admin',
    peer_staff_id: null,
    peer_nutritionist_id: null,
    peer_name: bizName,
    peer_subtitle: 'Διαχείριση γυμναστηρίου',
  });

  const [trainers] = await conn.execute(
    `SELECT DISTINCT s.id, s.full_name
     FROM bookings b
     INNER JOIN staff s ON s.id = b.staff_id
     WHERE b.user_id = ? AND b.business_id = ?
       AND b.status IN ('confirmed', 'completed')
       AND COALESCE(s.is_nutritionist, 0) = 0
       AND NOT EXISTS (
         SELECT 1 FROM nutritionists n
         WHERE n.business_id = ? AND n.staff_id = s.id AND n.is_active = 1
       )
     ORDER BY s.full_name`,
    [userId, bizId, bizId]
  );
  for (const s of trainers) {
    if (nutritionistStaffIds.has(s.id)) continue;
    const name = (s.full_name || '').trim() || 'Γυμναστής';
    peers.push({
      peer_role: 'trainer',
      peer_staff_id: s.id,
      peer_nutritionist_id: null,
      peer_name: name,
      peer_subtitle: 'Γυμναστής',
    });
  }

  const [hasNutrition] = await conn.execute(
    `SELECT 1 FROM user_memberships m
     LEFT JOIN business_plans p ON p.id = m.plan_id
     WHERE m.user_id = ? AND m.business_id = ?
       AND (
         m.service_category IN ('nutrition', 'nutrition_consultation')
         OR p.plan_type = 'nutrition'
       )
       AND COALESCE(m.membership_status, 'active') NOT IN ('trial', 'cancelled')
       AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())
     LIMIT 1`,
    [userId, bizId]
  );
  if (hasNutrition.length) {
    const [nutritionists] = await conn.execute(
      `SELECT id, full_name FROM nutritionists
       WHERE business_id = ? AND is_active = 1
       ORDER BY full_name`,
      [bizId]
    );
    for (const n of nutritionists) {
      const name = (n.full_name || '').trim() || 'Διατροφολόγος';
      peers.push({
        peer_role: 'nutritionist',
        peer_staff_id: null,
        peer_nutritionist_id: n.id,
        peer_name: name,
        peer_subtitle: 'Διατροφολόγος',
      });
    }
  }

  return peers;
}

async function listClientThreads(dbOrConn, bizId, userId) {
  const conn = dbOrConn;
  const nutritionistStaffIds = await getNutritionistStaffIds(conn, bizId);
  const [rows] = await conn.execute(
    `SELECT * FROM message_threads
     WHERE business_id = ? AND client_user_id = ?
     ORDER BY last_message_at DESC`,
    [bizId, userId]
  );
  const out = [];
  for (const row of rows) {
    if (row.peer_role === 'trainer' && row.peer_staff_id && nutritionistStaffIds.has(row.peer_staff_id)) {
      continue;
    }
    out.push(await formatClientThreadRow(conn, row));
  }
  return out;
}

async function getClientThreadById(dbOrConn, bizId, userId, threadId) {
  const conn = dbOrConn;
  const [rows] = await conn.execute(
    `SELECT * FROM message_threads
     WHERE id = ? AND business_id = ? AND client_user_id = ? LIMIT 1`,
    [threadId, bizId, userId]
  );
  if (!rows[0]) return null;
  const thread = await formatClientThreadRow(conn, rows[0]);
  const messages = await getThreadMessages(conn, threadId, { viewerRole: 'client' });
  return { thread, messages };
}

async function getClientUnreadCount(dbOrConn, bizId, userId) {
  const conn = dbOrConn;
  const [rows] = await conn.execute(
    `SELECT COALESCE(SUM(client_unread_count), 0) AS total
     FROM message_threads WHERE business_id = ? AND client_user_id = ?`,
    [bizId, userId]
  );
  return Number(rows[0]?.total || 0);
}

async function markClientThreadRead(dbOrConn, bizId, userId, threadId) {
  const conn = dbOrConn;
  const [rows] = await conn.execute(
    `SELECT id FROM message_threads
     WHERE id = ? AND business_id = ? AND client_user_id = ? LIMIT 1`,
    [threadId, bizId, userId]
  );
  if (!rows[0]) throw Object.assign(new Error('Η συνομιλία δεν βρέθηκε'), { status: 404 });

  await conn.execute(
    `UPDATE message_threads SET client_unread_count = 0 WHERE id = ?`,
    [threadId]
  );
  return { ok: true };
}

async function sendClientMessage(conn, actor, { body, threadId, peer: peerInput, attachment_url: attachmentUrl, message_type: messageType }) {
  const text = (body || '').trim();
  const type = messageType || (attachmentUrl ? 'image' : 'text');
  if (!text && !attachmentUrl) throw Object.assign(new Error('Κενό μήνυμα'), { status: 400 });
  if (type === 'image' && !attachmentUrl) {
    throw Object.assign(new Error('Απαιτείται εικόνα'), { status: 400 });
  }

  let threadRow;
  if (threadId) {
    const [rows] = await conn.execute(
      `SELECT id FROM message_threads
       WHERE id = ? AND business_id = ? AND client_user_id = ? LIMIT 1`,
      [threadId, actor.businessId, actor.userId]
    );
    if (!rows[0]) throw Object.assign(new Error('Η συνομιλία δεν βρέθηκε'), { status: 404 });
    threadRow = rows[0];
  } else {
    const peer = peerInput || parsePeerFromBody({ peer_role: 'admin' });
    const allowed = await validateClientCanMessagePeer(conn, actor.businessId, actor.userId, peer);
    if (!allowed) throw Object.assign(new Error('Δεν μπορείς να στείλεις μήνυμα σε αυτόν τον παραλήπτη'), { status: 403 });
    threadRow = await getOrCreateThread(conn, actor.businessId, actor.userId, peer);
  }

  const safeAttachment = validateAttachmentUrl(actor.businessId, threadRow.id, attachmentUrl);
  const client = await getUserDisplay(conn, actor.userId);
  const senderName = client?.name || 'Πελάτης';

  if (type === 'image') {
    await assertImageUploadAllowed(conn, {
      businessId: actor.businessId,
      senderRole: 'client',
      senderClientUserId: actor.userId,
    });
  }

  const msgId = uuidv4();
  const preview = buildMessagePreview({ body: text, message_type: type, attachment_url: safeAttachment });

  await conn.execute(
    `INSERT INTO messages
       (id, thread_id, business_id, sender_role, sender_client_user_id, sender_name, body, message_type, attachment_url)
     VALUES (?, ?, ?, 'client', ?, ?, ?, ?, ?)`,
    [msgId, threadRow.id, actor.businessId, actor.userId, senderName, text, type, safeAttachment]
  );

  await conn.execute(
    `UPDATE message_threads
     SET last_message_at = NOW(), last_message_preview = ?, staff_unread_count = staff_unread_count + 1
     WHERE id = ?`,
    [preview, threadRow.id]
  );

  const [threadMeta] = await conn.execute(
    `SELECT peer_role FROM message_threads WHERE id = ? LIMIT 1`,
    [threadRow.id]
  );
  if (threadMeta[0]?.peer_role === 'admin') {
    try {
      await createAdminNotification(conn, actor.businessId, {
        type: 'client_message',
        title: 'Νέο μήνυμα πελάτη',
        body: `${senderName}: ${preview}`,
        link: `/messages?client=${actor.userId}`,
      });
    } catch {
      /* non-fatal */
    }
  }

  const message = {
    id: msgId,
    thread_id: threadRow.id,
    sender_role: 'client',
    sender_name: senderName,
    body: text,
    message_type: type,
    attachment_url: safeAttachment,
    created_at: new Date(),
    is_mine: true,
  };

  return { message, thread_id: threadRow.id };
}

async function openClientThread(conn, bizId, userId, peer) {
  const allowed = await validateClientCanMessagePeer(conn, bizId, userId, peer);
  if (!allowed) throw Object.assign(new Error('Δεν μπορείς να ανοίξεις συνομιλία με αυτόν τον παραλήπτη'), { status: 403 });
  const threadRow = await getOrCreateThread(conn, bizId, userId, peer);
  return getClientThreadById(conn, bizId, userId, threadRow.id);
}

module.exports = {
  listStaffThreads,
  listStaffContacts,
  getThreadForStaff,
  getThreadMessages,
  sendStaffMessage,
  markStaffThreadRead,
  getStaffUnreadCount,
  canStaffAccessClient,
  getOrCreateThread,
  peerFromActor,
  listClientThreads,
  listClientPeers,
  getClientThreadById,
  getClientUnreadCount,
  markClientThreadRead,
  sendClientMessage,
  openClientThread,
  parsePeerFromBody,
  refreshThreadMetadata,
};
