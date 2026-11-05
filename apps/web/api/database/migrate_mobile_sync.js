'use strict';
// Explicit additive migration; importing never connects or changes a database.
const schema=`CREATE TABLE IF NOT EXISTS mobile_sync_receipts (
    org_id VARCHAR(50) NOT NULL, user_id INT NOT NULL,
    operation_id CHAR(36) NOT NULL, request_hash CHAR(64) NOT NULL,
    status_code SMALLINT NULL, result_json MEDIUMTEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (org_id,user_id,operation_id), INDEX idx_mobile_sync_created (created_at)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`;
async function migrateMobileSync(db) {
  await db.execute(schema);
}
module.exports = { migrateMobileSync, schema };
