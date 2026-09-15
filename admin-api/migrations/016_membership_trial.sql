-- Trial program: membership in trial status until converted to active package
ALTER TABLE user_memberships
  ADD COLUMN membership_status VARCHAR(20) NOT NULL DEFAULT 'active' AFTER notes,
  ADD COLUMN trial_booking_id CHAR(36) NULL AFTER membership_status;
