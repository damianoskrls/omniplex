-- Per-recipient message threads: client ↔ admin | trainer | nutritionist (private 1:1)

ALTER TABLE message_threads
  ADD COLUMN peer_role ENUM('admin', 'trainer', 'nutritionist') NOT NULL DEFAULT 'admin' AFTER client_user_id,
  ADD COLUMN peer_staff_id CHAR(36) NULL AFTER peer_role,
  ADD COLUMN peer_nutritionist_id CHAR(36) NULL AFTER peer_staff_id,
  ADD COLUMN peer_key VARCHAR(80) NOT NULL DEFAULT 'admin' AFTER peer_nutritionist_id;

UPDATE message_threads SET peer_role = 'admin', peer_key = 'admin' WHERE peer_key = 'admin';

ALTER TABLE message_threads DROP INDEX uq_thread_client;
ALTER TABLE message_threads ADD UNIQUE KEY uq_thread_peer (business_id, client_user_id, peer_key);
ALTER TABLE message_threads ADD KEY idx_threads_peer_staff (business_id, peer_staff_id, last_message_at DESC);
ALTER TABLE message_threads ADD KEY idx_threads_peer_nutritionist (business_id, peer_nutritionist_id, last_message_at DESC);
