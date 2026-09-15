-- Allow users to have no email (phone-only accounts)
ALTER TABLE users MODIFY COLUMN email VARCHAR(255) NULL DEFAULT NULL;

-- Clean up existing fake noemail.local addresses → set to NULL
UPDATE users SET email = NULL WHERE email LIKE '%@noemail.local';
