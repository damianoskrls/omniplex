#!/usr/bin/env node
/**
 * Move trainer/nutritionist messages out of admin threads into peer-specific threads.
 * Usage: node scripts/split-legacy-messages.js
 */
const { v4: uuidv4 } = require('uuid');
const db = require('../src/db');
const { getOrCreateThread, refreshThreadMetadata } = require('../src/lib/messages');

async function main() {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [misplaced] = await conn.execute(
      `SELECT m.id, m.thread_id, m.sender_role, m.sender_staff_id, m.sender_nutritionist_id,
              t.business_id, t.client_user_id
       FROM messages m
       INNER JOIN message_threads t ON t.id = m.thread_id
       WHERE t.peer_role = 'admin'
         AND m.sender_role IN ('trainer', 'nutritionist')`
    );

    const touchedThreads = new Set();
    let moved = 0;

    for (const row of misplaced) {
      let peer;
      if (row.sender_role === 'trainer') {
        if (!row.sender_staff_id) continue;
        peer = { peer_role: 'trainer', peer_staff_id: row.sender_staff_id, peer_nutritionist_id: null };
      } else {
        if (!row.sender_nutritionist_id) continue;
        peer = { peer_role: 'nutritionist', peer_staff_id: null, peer_nutritionist_id: row.sender_nutritionist_id };
      }

      const target = await getOrCreateThread(conn, row.business_id, row.client_user_id, peer);
      await conn.execute('UPDATE messages SET thread_id = ? WHERE id = ?', [target.id, row.id]);
      touchedThreads.add(row.thread_id);
      touchedThreads.add(target.id);
      moved += 1;
    }

    for (const threadId of touchedThreads) {
      await refreshThreadMetadata(conn, threadId);
    }

    await conn.commit();
    console.log(`Moved ${moved} message(s) across ${touchedThreads.size} thread(s).`);
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
    await db.end?.();
  }
}

main().catch((err) => {
  console.error('split-legacy-messages failed:', err.message);
  process.exit(1);
});
