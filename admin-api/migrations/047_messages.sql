CREATE TABLE IF NOT EXISTS message_threads (
  id CHAR(36) NOT NULL PRIMARY KEY,
  business_id CHAR(36) NOT NULL,
  client_user_id CHAR(36) NOT NULL,
  subject VARCHAR(255) DEFAULT NULL,
  last_message_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_message_preview VARCHAR(500) DEFAULT NULL,
  client_unread_count INT NOT NULL DEFAULT 0,
  staff_unread_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_thread_client (business_id, client_user_id),
  KEY idx_threads_business_updated (business_id, last_message_at DESC),
  KEY idx_threads_client (client_user_id),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (client_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS messages (
  id CHAR(36) NOT NULL PRIMARY KEY,
  thread_id CHAR(36) NOT NULL,
  business_id CHAR(36) NOT NULL,
  sender_role ENUM('client', 'admin', 'trainer', 'nutritionist') NOT NULL,
  sender_client_user_id CHAR(36) DEFAULT NULL,
  sender_staff_id CHAR(36) DEFAULT NULL,
  sender_nutritionist_id CHAR(36) DEFAULT NULL,
  sender_name VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_messages_thread (thread_id, created_at),
  FOREIGN KEY (thread_id) REFERENCES message_threads(id) ON DELETE CASCADE
);
