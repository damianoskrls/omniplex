// Community feed routes
// Mobile: /api/community/:bizId/...
// Admin:  /api/client-admin/community/...
const router = require('express').Router({ mergeParams: true });
const { v4: uuid } = require('uuid');
const jwt = require('jsonwebtoken');
const db = require('../db');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { createUserNotification } = require('../lib/user_notifications');

// ── helpers ──────────────────────────────────────────────────────────────────

function requireMobile(req, res, next) {
  const auth = req.headers.authorization || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ error: 'Unauthorized' });
  }
}

function requireClientAdmin(req, res, next) {
  const auth = req.headers.authorization || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  try {
    const d = jwt.verify(token, process.env.JWT_SECRET);
    if (!d.businessId) return res.status(403).json({ error: 'Forbidden' });
    req.admin = d;
    next();
  } catch {
    return res.status(401).json({ error: 'Unauthorized' });
  }
}

const uploadDir = process.env.UPLOAD_DIR || './uploads';

function bizUpload(bizId) {
  const dir = path.join(uploadDir, bizId, 'community');
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  return multer({
    storage: multer.diskStorage({
      destination: (_, __, cb) => cb(null, dir),
      filename: (_, file, cb) => cb(null, `${uuid()}${path.extname(file.originalname)}`),
    }),
    limits: { fileSize: 50 * 1024 * 1024 },
    fileFilter: (_, file, cb) => {
      // Accept images/videos; also accept octet-stream (common from mobile multipart without explicit content-type)
      const ok = /image\/(jpeg|png|gif|webp)|video\/(mp4|quicktime|webm)|application\/octet-stream/.test(file.mimetype);
      cb(null, ok);
    },
  });
}

async function enrichPosts(posts, viewerUserId, viewerStaffId) {
  if (!posts.length) return [];
  const postIds = posts.map(p => p.id);
  const placeholders = postIds.map(() => '?').join(',');

  const [media] = await db.query(
    `SELECT post_id, media_url, media_type, sort_order FROM community_post_media WHERE post_id IN (${placeholders}) ORDER BY sort_order`,
    postIds,
  );
  const [reactions] = await db.query(
    `SELECT post_id, COUNT(*) AS cnt FROM community_reactions WHERE post_id IN (${placeholders}) GROUP BY post_id`,
    postIds,
  );
  const [comments] = await db.query(
    `SELECT c.id, c.post_id, c.body, c.created_at,
            u.full_name AS user_name, u.id AS user_id,
            st.full_name AS staff_name, st.id AS staff_id, st.avatar_url AS staff_avatar
     FROM community_comments c
     LEFT JOIN users u ON u.id = c.user_id
     LEFT JOIN staff st ON st.id = c.staff_id
     WHERE c.post_id IN (${placeholders}) AND c.deleted_at IS NULL
     ORDER BY c.created_at ASC`,
    postIds,
  );

  // Did this viewer react?
  let myReactions = [];
  if (viewerUserId || viewerStaffId) {
    const col = viewerUserId ? 'user_id' : 'staff_id';
    const val = viewerUserId || viewerStaffId;
    const [rows] = await db.query(
      `SELECT post_id FROM community_reactions WHERE post_id IN (${placeholders}) AND ${col} = ?`,
      [...postIds, val],
    );
    myReactions = rows.map(r => r.post_id);
  }

  const mediaMap = {};
  for (const m of media) {
    if (!mediaMap[m.post_id]) mediaMap[m.post_id] = [];
    mediaMap[m.post_id].push({ url: m.media_url, type: m.media_type });
  }
  const reactMap = Object.fromEntries(reactions.map(r => [r.post_id, Number(r.cnt)]));
  const commentMap = {};
  for (const c of comments) {
    if (!commentMap[c.post_id]) commentMap[c.post_id] = [];
    commentMap[c.post_id].push(c);
  }

  return posts.map(p => {
    const isPinned = p.is_pinned === 1;
    const pinnedUntil = p.pinned_until ? new Date(p.pinned_until) : null;
    const pinActive = isPinned && (!pinnedUntil || pinnedUntil > new Date());
    return {
      ...p,
      media: mediaMap[p.id] || [],
      reaction_count: reactMap[p.id] || 0,
      liked: myReactions.includes(p.id),
      comments: commentMap[p.id] || [],
      is_pinned: pinActive,
      pinned_until: p.pinned_until ? new Date(p.pinned_until).toISOString() : null,
    };
  });
}

// ── Mobile routes  (/api/community/:bizId/) ──────────────────────────────────

// GET /api/community/:bizId/posts?cursor=&limit=20
router.get('/mobile/:bizId/posts', requireMobile, async (req, res) => {
  const { bizId } = req.params;
  const limit = Math.min(parseInt(req.query.limit || '20'), 50);
  const cursor = req.query.cursor || null;

  try {
    const [rows] = await db.query(`
      SELECT p.id, p.body, p.created_at, p.is_pinned, p.pinned_until,
             u.id AS user_id, u.full_name AS user_name, u.phone AS user_phone,
             st.id AS staff_id, st.full_name AS staff_name, st.avatar_url AS staff_avatar, st.role AS staff_role
      FROM community_posts p
      LEFT JOIN users u ON u.id = p.user_id
      LEFT JOIN staff st ON st.id = p.staff_id
      WHERE p.business_id = ? AND p.deleted_at IS NULL
        ${cursor ? 'AND (p.is_pinned = 0 OR (p.pinned_until IS NOT NULL AND p.pinned_until < NOW())) AND p.created_at < (SELECT created_at FROM community_posts WHERE id = ?)' : ''}
      ORDER BY
        CASE WHEN p.is_pinned = 1 AND (p.pinned_until IS NULL OR p.pinned_until > NOW()) THEN 0 ELSE 1 END ASC,
        p.created_at DESC
      LIMIT ?
    `, cursor ? [bizId, cursor, limit + 1] : [bizId, limit + 1]);

    const hasMore = rows.length > limit;
    const data = rows.slice(0, limit);
    const enriched = await enrichPosts(data, req.user.userId, null);
    return res.json({ posts: enriched, next_cursor: hasMore ? data[data.length - 1]?.id : null });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/community/:bizId/posts
router.post('/mobile/:bizId/posts', requireMobile, async (req, res) => {
  const { bizId } = req.params;
  const { body, media, mentions } = req.body; // mentions: [{user_id?, staff_id?}]
  if (!body?.trim() && (!media || !media.length)) {
    return res.status(400).json({ error: 'Κείμενο ή μέσο απαιτείται' });
  }
  try {
    const [[user]] = await db.query('SELECT id, full_name FROM users WHERE id = ? AND business_id = ?', [req.user.userId, bizId]);
    if (!user) return res.status(403).json({ error: 'Δεν έχεις πρόσβαση' });

    const postId = uuid();
    await db.query(
      'INSERT INTO community_posts (id, business_id, user_id, body) VALUES (?, ?, ?, ?)',
      [postId, bizId, req.user.userId, body?.trim() || null],
    );
    if (media?.length) {
      for (let i = 0; i < media.length; i++) {
        await db.query(
          'INSERT INTO community_post_media (id, post_id, media_url, media_type, sort_order) VALUES (?,?,?,?,?)',
          [uuid(), postId, media[i].url, media[i].type || 'image', i],
        );
      }
    }

    // Notify admin about new post
    await db.query(
      `INSERT INTO admin_notifications (id, business_id, type, title, body, payload) VALUES (?,?,?,?,?,?)`,
      [uuid(), bizId, 'community_post', 'Νέα ανάρτηση', `${user.full_name}: ${(body || '').slice(0, 80)}`, JSON.stringify({ post_id: postId })],
    );

    // Notify mentioned users
    if (Array.isArray(mentions)) {
      for (const m of mentions) {
        if (m.user_id && m.user_id !== req.user.userId) {
          await createUserNotification(db, {
            businessId: bizId, userId: m.user_id, type: 'community_mention',
            title: 'Σε ανέφεραν σε ανάρτηση', body: `${user.full_name}: ${(body || '').slice(0, 80)}`,
            payload: { post_id: postId }, sendPush: true,
          });
        }
      }
    }

    const [[post]] = await db.query(`
      SELECT p.id, p.body, p.created_at, u.id AS user_id, u.full_name AS user_name
      FROM community_posts p LEFT JOIN users u ON u.id = p.user_id WHERE p.id = ?`, [postId]);
    const [enriched] = await enrichPosts([post], req.user.userId, null);
    return res.status(201).json(enriched);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/community/:bizId/posts/upload-media  (multipart)
router.post('/mobile/:bizId/posts/upload-media', requireMobile, (req, res) => {
  const { bizId } = req.params;
  const upload = bizUpload(bizId);
  upload.array('files', 10)(req, res, async (err) => {
    if (err) return res.status(400).json({ error: err.message });
    const files = req.files || [];
    const result = files.map(f => ({
      url: `/uploads/${bizId}/community/${f.filename}`,
      type: f.mimetype.startsWith('video') ? 'video' : 'image',
    }));
    return res.json({ media: result });
  });
});

// POST /api/community/:bizId/posts/:postId/react
router.post('/mobile/:bizId/posts/:postId/react', requireMobile, async (req, res) => {
  const { bizId, postId } = req.params;
  try {
    const [[exists]] = await db.query(
      'SELECT id FROM community_reactions WHERE post_id = ? AND user_id = ?',
      [postId, req.user.userId],
    );
    if (exists) {
      await db.query('DELETE FROM community_reactions WHERE post_id = ? AND user_id = ?', [postId, req.user.userId]);
      return res.json({ liked: false });
    } else {
      await db.query(
        'INSERT INTO community_reactions (id, post_id, user_id) VALUES (?,?,?)',
        [uuid(), postId, req.user.userId],
      );
      return res.json({ liked: true });
    }
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/community/:bizId/posts/:postId/comments
router.post('/mobile/:bizId/posts/:postId/comments', requireMobile, async (req, res) => {
  const { bizId, postId } = req.params;
  const { body, mentions } = req.body;
  if (!body?.trim()) return res.status(400).json({ error: 'Κείμενο απαιτείται' });
  try {
    const [[user]] = await db.query('SELECT id, full_name FROM users WHERE id = ?', [req.user.userId]);
    const commentId = uuid();
    await db.query(
      'INSERT INTO community_comments (id, post_id, user_id, body) VALUES (?,?,?,?)',
      [commentId, postId, req.user.userId, body.trim()],
    );
    // Notify mentioned users
    if (Array.isArray(mentions) && user) {
      for (const m of mentions) {
        if (m.user_id && m.user_id !== req.user.userId) {
          await createUserNotification(db, {
            businessId: bizId, userId: m.user_id, type: 'community_mention',
            title: 'Σε ανέφεραν σε σχόλιο', body: `${user.full_name}: ${body.trim().slice(0, 80)}`,
            payload: { post_id: postId }, sendPush: true,
          });
        }
      }
    }
    // Notify post author if someone else commented
    if (user) {
      const [[post]] = await db.query('SELECT user_id FROM community_posts WHERE id = ?', [postId]);
      if (post?.user_id && post.user_id !== req.user.userId) {
        await createUserNotification(db, {
          businessId: bizId, userId: post.user_id, type: 'community_comment',
          title: 'Νέο σχόλιο στην ανάρτησή σου', body: `${user.full_name}: ${body.trim().slice(0, 80)}`,
          payload: { post_id: postId }, sendPush: true,
        });
      }
    }
    const [[comment]] = await db.query(`
      SELECT c.id, c.post_id, c.body, c.created_at,
             u.full_name AS user_name, u.id AS user_id
      FROM community_comments c LEFT JOIN users u ON u.id = c.user_id WHERE c.id = ?`, [commentId]);
    return res.status(201).json(comment);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/community/mobile/:bizId/comments/:commentId  (own comment only)
router.delete('/mobile/:bizId/comments/:commentId', requireMobile, async (req, res) => {
  const { commentId } = req.params;
  try {
    await db.query(
      'UPDATE community_comments SET deleted_at = NOW() WHERE id = ? AND user_id = ?',
      [commentId, req.user.userId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/community/mobile/:bizId/mentionables  (members + staff for @mention picker)
router.get('/mobile/:bizId/mentionables', requireMobile, async (req, res) => {
  const { bizId } = req.params;
  try {
    const [users] = await db.query(
      `SELECT id AS user_id, full_name, NULL AS staff_id FROM users WHERE business_id = ? AND deleted_at IS NULL AND id != ? LIMIT 100`,
      [bizId, req.user.userId],
    );
    const [staff] = await db.query(
      `SELECT NULL AS user_id, full_name, id AS staff_id FROM staff WHERE business_id = ? AND is_active = 1 LIMIT 50`,
      [bizId],
    );
    return res.json({ mentionables: [...staff, ...users] });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/community/mobile/:bizId/posts/:postId  (own post only)
router.delete('/mobile/:bizId/posts/:postId', requireMobile, async (req, res) => {
  const { postId } = req.params;
  try {
    await db.query(
      'UPDATE community_posts SET deleted_at = NOW() WHERE id = ? AND user_id = ?',
      [postId, req.user.userId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── Admin routes  (/api/client-admin/community/...) ──────────────────────────

// GET /api/client-admin/community/posts?cursor=&limit=30
router.get('/admin/posts', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const limit = Math.min(parseInt(req.query.limit || '30'), 100);
  const cursor = req.query.cursor || null;
  try {
    const [rows] = await db.query(`
      SELECT p.id, p.body, p.created_at, p.deleted_at, p.is_pinned, p.pinned_until,
             u.id AS user_id, u.full_name AS user_name,
             st.id AS staff_id, st.full_name AS staff_name, st.avatar_url AS staff_avatar
      FROM community_posts p
      LEFT JOIN users u ON u.id = p.user_id
      LEFT JOIN staff st ON st.id = p.staff_id
      WHERE p.business_id = ?
        ${cursor ? 'AND (p.is_pinned = 0 OR (p.pinned_until IS NOT NULL AND p.pinned_until < NOW())) AND p.created_at < (SELECT created_at FROM community_posts WHERE id = ?)' : ''}
      ORDER BY
        CASE WHEN p.is_pinned = 1 AND (p.pinned_until IS NULL OR p.pinned_until > NOW()) THEN 0 ELSE 1 END ASC,
        p.created_at DESC
      LIMIT ?
    `, cursor ? [bizId, cursor, limit + 1] : [bizId, limit + 1]);

    const hasMore = rows.length > limit;
    const data = rows.slice(0, limit);
    const enriched = await enrichPosts(data, null, null);
    return res.json({ posts: enriched, next_cursor: hasMore ? data[data.length - 1]?.id : null });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/client-admin/community/posts/:postId  (admin soft delete)
router.delete('/admin/posts/:postId', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    await db.query(
      'UPDATE community_posts SET deleted_at = NOW() WHERE id = ? AND business_id = ?',
      [req.params.postId, bizId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/client-admin/community/admin/posts/:postId/pin
router.patch('/admin/posts/:postId/pin', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { pin, pinned_until } = req.body; // pin: bool, pinned_until: ISO string or null
  try {
    const until = pin && pinned_until ? new Date(pinned_until) : null;
    await db.query(
      'UPDATE community_posts SET is_pinned = ?, pinned_until = ? WHERE id = ? AND business_id = ?',
      [pin ? 1 : 0, until || null, req.params.postId, bizId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/client-admin/community/comments/:commentId
router.delete('/admin/comments/:commentId', requireClientAdmin, async (req, res) => {
  try {
    await db.query('UPDATE community_comments SET deleted_at = NOW() WHERE id = ?', [req.params.commentId]);
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/client-admin/community/mentionables
router.get('/admin/mentionables', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [users] = await db.query(
      `SELECT id AS user_id, full_name, NULL AS staff_id FROM users WHERE business_id = ? AND deleted_at IS NULL LIMIT 100`,
      [bizId],
    );
    const [staff] = await db.query(
      `SELECT NULL AS user_id, full_name, id AS staff_id FROM staff WHERE business_id = ? AND is_active = 1 LIMIT 50`,
      [bizId],
    );
    return res.json({ mentionables: [...staff, ...users] });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/client-admin/community/posts  (admin/secretary posts to feed)
router.post('/admin/posts', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { body, media, staff_id, mentions } = req.body;
  if (!body?.trim() && (!media || !media.length)) {
    return res.status(400).json({ error: 'Κείμενο ή μέσο απαιτείται' });
  }
  try {
    const postId = uuid();
    await db.query(
      'INSERT INTO community_posts (id, business_id, staff_id, body) VALUES (?, ?, ?, ?)',
      [postId, bizId, staff_id || null, body?.trim() || null],
    );
    if (media?.length) {
      for (let i = 0; i < media.length; i++) {
        await db.query(
          'INSERT INTO community_post_media (id, post_id, media_url, media_type, sort_order) VALUES (?,?,?,?,?)',
          [uuid(), postId, media[i].url, media[i].type || 'image', i],
        );
      }
    }
    // Notify mentioned users
    if (Array.isArray(mentions)) {
      for (const m of mentions) {
        if (m.user_id) {
          await createUserNotification(db, {
            businessId: bizId, userId: m.user_id, type: 'community_mention',
            title: 'Σε ανέφεραν', body: body?.slice(0, 80) || 'Νέα ανάρτηση',
            payload: { post_id: postId },
          });
        }
      }
    }
    return res.status(201).json({ id: postId });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/client-admin/community/posts/:postId/comments  (admin comments on a post)
router.post('/admin/posts/:postId/comments', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { postId } = req.params;
  const { body, mentions } = req.body;
  if (!body?.trim()) return res.status(400).json({ error: 'Κείμενο απαιτείται' });
  const staffId = req.admin.staffId || null;
  try {
    const commentId = uuid();
    await db.query(
      'INSERT INTO community_comments (id, post_id, staff_id, body) VALUES (?,?,?,?)',
      [commentId, postId, staffId, body.trim()],
    );
    // Notify post author (user)
    const [[post]] = await db.query('SELECT user_id FROM community_posts WHERE id = ?', [postId]);
    if (post?.user_id) {
      await createUserNotification(db, {
        businessId: bizId, userId: post.user_id, type: 'community_comment',
        title: 'Νέο σχόλιο', body: body.slice(0, 80),
        payload: { post_id: postId },
      });
    }
    // Notify mentioned users
    if (Array.isArray(mentions)) {
      for (const m of mentions) {
        if (m.user_id && m.user_id !== post?.user_id) {
          await createUserNotification(db, {
            businessId: bizId, userId: m.user_id, type: 'community_mention',
            title: 'Σε ανέφεραν σε σχόλιο', body: body.slice(0, 80),
            payload: { post_id: postId },
          });
        }
      }
    }
    const [[comment]] = await db.query(`
      SELECT cc.id, cc.body, cc.created_at,
             st.id AS staff_id, st.full_name AS staff_name, st.avatar_url AS staff_avatar
      FROM community_comments cc
      LEFT JOIN staff st ON st.id = cc.staff_id
      WHERE cc.id = ?
    `, [commentId]);
    return res.status(201).json(comment);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/client-admin/community/upload-media
router.post('/admin/upload-media', requireClientAdmin, (req, res) => {
  const bizId = req.admin.businessId;
  const upload = bizUpload(bizId);
  upload.array('files', 10)(req, res, async (err) => {
    if (err) return res.status(400).json({ error: err.message });
    const files = req.files || [];
    const result = files.map(f => ({
      url: `/uploads/${bizId}/community/${f.filename}`,
      type: f.mimetype.startsWith('video') ? 'video' : 'image',
    }));
    return res.json({ media: result });
  });
});

// GET /api/client-admin/community/secretary-contacts
// Returns staff that have role='secretary' or role='admin' — usable as DM targets from mobile
router.get('/admin/secretary-contacts', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [rows] = await db.query(
      `SELECT id, full_name, avatar_url, role FROM staff WHERE business_id = ? AND is_active = 1 AND role IN ('admin','secretary','receptionist','γραμματεία')`,
      [bizId],
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

module.exports = router;
