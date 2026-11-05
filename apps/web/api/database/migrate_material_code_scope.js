'use strict';
// Explicit administrator operation. Importing this module never connects or migrates.
async function migrateMaterialCodeScope(db) {
  const [missing] = await db.execute('SELECT COUNT(*) AS total FROM materials WHERE org_id IS NULL OR org_id=\'\'');
  if (Number(missing[0].total)) throw Error('MATERIAL_ORGANIZATION_REQUIRED');
  const [duplicates] = await db.execute('SELECT org_id,code FROM materials GROUP BY org_id,code HAVING COUNT(*)>1 LIMIT 1');
  if (duplicates.length) throw Error('DUPLICATE_MATERIAL_CODES');
  const [indexes] = await db.execute('SELECT INDEX_NAME,COLUMN_NAME,SEQ_IN_INDEX,NON_UNIQUE FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=\'materials\' ORDER BY INDEX_NAME,SEQ_IN_INDEX');
  const unique = new Map();
  for (const row of indexes) if (Number(row.NON_UNIQUE) === 0) {
    if (!unique.has(row.INDEX_NAME)) unique.set(row.INDEX_NAME, []);
    unique.get(row.INDEX_NAME).push(row.COLUMN_NAME);
  }
  const scoped = [...unique.values()].some(columns => columns.join(',') === 'org_id,code');
  if (!scoped) await db.execute('ALTER TABLE materials ADD UNIQUE KEY uq_material_org_code (org_id,code)');
  for (const [name, columns] of unique) {
    if (columns.join(',') !== 'code') continue;
    // Identifiers originate in metadata and are validated before interpolation.
    if (!/^[a-zA-Z0-9_]{1,64}$/.test(name)) throw Error('UNEXPECTED_MATERIAL_INDEX');
    await db.execute('ALTER TABLE materials DROP INDEX `' + name + '`');
  }
}
module.exports = { migrateMaterialCodeScope };
