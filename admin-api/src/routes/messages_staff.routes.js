const express = require('express');
const jwt = require('jsonwebtoken');
const db = require('../db');
const {
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
} = require('../lib/messages');
const { createMessageUpload, publicUploadPath, handleMessageUpload } = require('../lib/message_upload');
const { assertImageUploadAllowed } = require('../lib/message_attachments');

const router = express.Router();

const staffMessageUpload = createMessageUpload((req) => ({
  businessId: req.admin.businessId,
  threadId: req.params.threadId,
}));

function requireStaffMessaging(req, res, next) {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ error: 'No token' });
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  try {
    const d = jwt.verify(token, process.env.JWT_SECRET);
    if (!['client_admin', 'trainer', 'nutritionist'].includes(d.role)) {
      return res.status(403).json({ error: 'Not authorized' });
    }
    req.admin = d;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

function actorFromAdmin(admin) {
  return {
    role: admin.role,
    businessId: admin.businessId,
    staffId: admin.staffId || null,
    nutritionistId: admin.nutritionistId || null,
  };
}

router.get('/threads', requireStaffMessaging, async (req, res) => {
  try {
    const threads = await listStaffThreads(db, actorFromAdmin(req.admin), {
      q: req.query.q || '',
      limit: Number(req.query.limit) || 50,
    });
    return res.json(threads);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get('/contacts', requireStaffMessaging, async (req, res) => {
  try {
    const contacts = await listStaffContacts(db, actorFromAdmin(req.admin), {
      q: req.query.q || '',
      limit: Number(req.query.limit) || 30,
    });
    return res.json(contacts);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get('/unread-count', requireStaffMessaging, async (req, res) => {
  try {
    const count = await getStaffUnreadCount(db, actorFromAdmin(req.admin));
    return res.json({ unread_count: count });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/threads', requireStaffMessaging, async (req, res) => {
  const { client_user_id } = req.body || {};
  if (!client_user_id) return res.status(400).json({ error: 'Απαιτείται πελάτης' });

  const conn = await db.getConnection();
  try {
    const actor = actorFromAdmin(req.admin);
    const client = await canStaffAccessClient(conn, actor, client_user_id);
    if (!client) return res.status(403).json({ error: 'Δεν μπορείς να ανοίξεις συνομιλία με αυτόν τον πελάτη' });

    const threadRow = await getOrCreateThread(conn, actor.businessId, client_user_id, peerFromActor(actor));
    const thread = await getThreadForStaff(conn, actor, threadRow.id);
    const messages = await getThreadMessages(conn, threadRow.id, {
      viewerRole: actor.role === 'client_admin' ? 'client_admin' : actor.role,
      viewerId: actor.staffId || actor.nutritionistId,
    });
    return res.status(201).json({ thread, messages });
  } catch (err) {
    return res.status(err.status || 500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.get('/threads/:threadId', requireStaffMessaging, async (req, res) => {
  try {
    const actor = actorFromAdmin(req.admin);
    const thread = await getThreadForStaff(db, actor, req.params.threadId);
    if (!thread) return res.status(404).json({ error: 'Η συνομιλία δεν βρέθηκε' });

    const messages = await getThreadMessages(db, req.params.threadId, {
      viewerRole: actor.role === 'client_admin' ? 'client_admin' : actor.role,
      viewerId: actor.staffId || actor.nutritionistId,
    });
    return res.json({ thread, messages });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/threads/:threadId/upload', requireStaffMessaging, handleMessageUpload(staffMessageUpload), async (req, res) => {
  try {
    const actor = actorFromAdmin(req.admin);
    const thread = await getThreadForStaff(db, actor, req.params.threadId);
    if (!thread) return res.status(404).json({ error: 'Η συνομιλία δεν βρέθηκε' });
    if (!req.file) return res.status(400).json({ error: 'Απαιτείται εικόνα' });

    if (actor.role === 'client_admin') {
      await assertImageUploadAllowed(db, {
        businessId: actor.businessId,
        senderRole: 'admin',
      });
    } else if (actor.role === 'trainer') {
      await assertImageUploadAllowed(db, {
        businessId: actor.businessId,
        senderRole: 'trainer',
        senderStaffId: actor.staffId,
      });
    } else {
      await assertImageUploadAllowed(db, {
        businessId: actor.businessId,
        senderRole: 'nutritionist',
        senderNutritionistId: actor.nutritionistId,
      });
    }

    const attachment_url = publicUploadPath(req.admin.businessId, req.params.threadId, req.file.filename);
    return res.json({ attachment_url });
  } catch (err) {
    return res.status(err.status || 500).json({ error: err.message });
  }
});

router.post('/threads/:threadId/messages', requireStaffMessaging, async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const result = await sendStaffMessage(conn, actorFromAdmin(req.admin), {
      threadId: req.params.threadId,
      body: req.body?.body,
      attachment_url: req.body?.attachment_url,
      message_type: req.body?.message_type,
    });
    await conn.commit();
    return res.status(201).json(result);
  } catch (err) {
    await conn.rollback();
    return res.status(err.status || 500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.post('/threads/:threadId/read', requireStaffMessaging, async (req, res) => {
  try {
    const result = await markStaffThreadRead(db, actorFromAdmin(req.admin), req.params.threadId);
    return res.json(result);
  } catch (err) {
    return res.status(err.status || 500).json({ error: err.message });
  }
});

module.exports = router;
