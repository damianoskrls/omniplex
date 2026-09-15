const fs = require('fs');
const path = require('path');

const MESSAGE_IMAGE_RETENTION_HOURS = Number(process.env.MESSAGE_IMAGE_RETENTION_HOURS || 24);
const MAX_MESSAGE_IMAGES_PER_DAY = Number(process.env.MAX_MESSAGE_IMAGES_PER_DAY || 10);
const MESSAGE_ORPHAN_GRACE_HOURS = Number(process.env.MESSAGE_ORPHAN_GRACE_HOURS || 1);

function uploadRoot() {
  return path.resolve(process.env.UPLOAD_DIR || './uploads');
}

function attachmentUrlToDiskPath(attachmentUrl) {
  if (!attachmentUrl || !String(attachmentUrl).startsWith('/uploads/')) return null;
  const rel = String(attachmentUrl).replace(/^\/uploads\//, '');
  return path.join(uploadRoot(), rel);
}

function deleteAttachmentFile(attachmentUrl) {
  const diskPath = attachmentUrlToDiskPath(attachmentUrl);
  if (!diskPath) return false;
  try {
    if (fs.existsSync(diskPath)) {
      fs.unlinkSync(diskPath);
      return true;
    }
  } catch {
    /* ignore */
  }
  return false;
}

async function countRecentImageMessages(conn, {
  businessId,
  senderRole,
  senderClientUserId = null,
  senderStaffId = null,
  senderNutritionistId = null,
}) {
  let sql = `
    SELECT COUNT(*) AS cnt FROM messages
    WHERE business_id = ?
      AND message_type = 'image'
      AND attachment_url IS NOT NULL
      AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
  `;
  const params = [businessId];

  if (senderRole === 'client') {
    sql += ` AND sender_role = 'client' AND sender_client_user_id = ?`;
    params.push(senderClientUserId);
  } else if (senderRole === 'trainer') {
    sql += ` AND sender_role = 'trainer' AND sender_staff_id = ?`;
    params.push(senderStaffId);
  } else if (senderRole === 'nutritionist') {
    sql += ` AND sender_role = 'nutritionist' AND sender_nutritionist_id = ?`;
    params.push(senderNutritionistId);
  } else {
    sql += ` AND sender_role = 'admin'`;
  }

  const [[row]] = await conn.execute(sql, params);
  return Number(row?.cnt || 0);
}

async function assertImageUploadAllowed(conn, sender) {
  const count = await countRecentImageMessages(conn, sender);
  if (count >= MAX_MESSAGE_IMAGES_PER_DAY) {
    throw Object.assign(
      new Error(`Έφτασες το όριο ${MAX_MESSAGE_IMAGES_PER_DAY} εικόνων ανά 24 ώρες`),
      { status: 429 },
    );
  }
}

async function purgeExpiredMessageAttachments(conn) {
  const [rows] = await conn.query(
    `SELECT id, attachment_url FROM messages
     WHERE message_type = 'image'
       AND attachment_url IS NOT NULL
       AND created_at < DATE_SUB(NOW(), INTERVAL ? HOUR)`,
    [MESSAGE_IMAGE_RETENTION_HOURS],
  );

  let removed = 0;
  for (const row of rows) {
    deleteAttachmentFile(row.attachment_url);
    await conn.execute(
      `UPDATE messages SET attachment_url = NULL WHERE id = ?`,
      [row.id],
    );
    removed += 1;
  }
  return removed;
}

function walkMessageImageFiles(rootDir) {
  const files = [];
  if (!fs.existsSync(rootDir)) return files;

  for (const businessId of fs.readdirSync(rootDir)) {
    const messagesDir = path.join(rootDir, businessId, 'messages');
    if (!fs.existsSync(messagesDir) || !fs.statSync(messagesDir).isDirectory()) continue;

    for (const threadId of fs.readdirSync(messagesDir)) {
      const threadDir = path.join(messagesDir, threadId);
      if (!fs.statSync(threadDir).isDirectory()) continue;

      for (const filename of fs.readdirSync(threadDir)) {
        const fullPath = path.join(threadDir, filename);
        if (!fs.statSync(fullPath).isFile()) continue;
        files.push({
          fullPath,
          attachmentUrl: `/uploads/${businessId}/messages/${threadId}/${filename}`,
        });
      }
    }
  }
  return files;
}

async function purgeOrphanMessageFiles(conn) {
  const rootDir = uploadRoot();
  const [rows] = await conn.query(
    `SELECT attachment_url FROM messages WHERE attachment_url IS NOT NULL`,
  );
  const referenced = new Set(rows.map((r) => r.attachment_url));
  const cutoff = Date.now() - MESSAGE_ORPHAN_GRACE_HOURS * 60 * 60 * 1000;

  let removed = 0;
  for (const file of walkMessageImageFiles(rootDir)) {
    if (referenced.has(file.attachmentUrl)) continue;
    try {
      const stat = fs.statSync(file.fullPath);
      if (stat.mtimeMs > cutoff) continue;
      fs.unlinkSync(file.fullPath);
      removed += 1;
    } catch {
      /* ignore */
    }
  }
  return removed;
}

async function processMessageAttachmentCleanup() {
  const conn = await require('../db').getConnection();
  try {
    const expired = await purgeExpiredMessageAttachments(conn);
    const orphans = await purgeOrphanMessageFiles(conn);
    if (expired || orphans) {
      console.log(`✓ Message attachments: ${expired} expired, ${orphans} orphan files removed`);
    }
  } catch (err) {
    console.error('Message attachment cleanup failed:', err.message);
  } finally {
    conn.release();
  }
}

function startMessageAttachmentWorker(intervalMs = 60 * 60 * 1000) {
  processMessageAttachmentCleanup();
  setInterval(processMessageAttachmentCleanup, intervalMs);
  console.log(` Message attachment cleanup started (every ${Math.round(intervalMs / 60000)}m)`);
}

module.exports = {
  MESSAGE_IMAGE_RETENTION_HOURS,
  MAX_MESSAGE_IMAGES_PER_DAY,
  attachmentUrlToDiskPath,
  deleteAttachmentFile,
  countRecentImageMessages,
  assertImageUploadAllowed,
  purgeExpiredMessageAttachments,
  purgeOrphanMessageFiles,
  processMessageAttachmentCleanup,
  startMessageAttachmentWorker,
};
