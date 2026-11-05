'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {validProfileImage}=require('../../api/security/profile-image');
test('avatar accepts genuine PNG signature and rejects disguised content, URLs and excessive sizes',()=>{
 const png='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jgXkAAAAASUVORK5CYII=';
 assert.equal(validProfileImage(png),true);
 for(const value of ['https://example.invalid/avatar.png','data:image/svg+xml;base64,PHN2Zy8+','data:image/png;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==','data:image/webp;base64,UklGRg==',png+'A'.repeat(2_000_000)])assert.equal(validProfileImage(value),false);
});
