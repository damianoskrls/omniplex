USE bookup;

CREATE TABLE IF NOT EXISTS staff_availability_requests (
  id CHAR(36) PRIMARY KEY,
  staff_id CHAR(36) NOT NULL,
  business_id CHAR(36) NOT NULL,
  service_id CHAR(36) DEFAULT NULL,
  status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
  proposed_slots JSON NOT NULL,
  submitted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at TIMESTAMP NULL DEFAULT NULL,
  reviewed_by VARCHAR(255) DEFAULT NULL,
  review_note TEXT DEFAULT NULL,
  CONSTRAINT fk_avail_req_staff FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE,
  CONSTRAINT fk_avail_req_business FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  INDEX idx_avail_req_staff_status (staff_id, status),
  INDEX idx_avail_req_business_status (business_id, status)
);
