ALTER TABLE messages
  ADD COLUMN message_type ENUM('text', 'image') NOT NULL DEFAULT 'text',
  ADD COLUMN attachment_url VARCHAR(500) NULL;
