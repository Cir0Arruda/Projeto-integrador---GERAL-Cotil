const path = require('node:path');
const MAX_BYTES = 10 * 1024 * 1024;
// A repeated four-character group can exhaust V8's regexp backtracking stack
// for valid multi-megabyte CAD/glTF payloads. Keep the scan flat and bounded.
function validBase64(value) {
  return value.length % 4 === 0 && /^[A-Za-z0-9+/]*={0,2}$/.test(value);
}
function embeddedResource(uri) {
  if (typeof uri !== 'string') return false;
  const prefix = /^data:(?:application\/(?:octet-stream|gltf-buffer)|image\/(?:png|jpeg|webp));base64,/.exec(uri);
  return Boolean(prefix) && validBase64(uri.slice(prefix[0].length));
}
function selfContainedGltf(data) {
  if (!data || data.asset?.version !== '2.0') return false;
  const resources = [];
  for (const key of ['buffers', 'images']) {
    if (data[key] !== undefined && !Array.isArray(data[key])) return false;
    resources.push(...(data[key] || []));
  }
  return resources.every(resource => resource && typeof resource === 'object' && !Array.isArray(resource) &&
    (resource.uri === undefined || embeddedResource(resource.uri)));
}
function selfContainedGlb(buf) {
  if (buf.length < 20 || buf.toString('ascii', 0, 4) !== 'glTF' ||
      buf.readUInt32LE(4) !== 2 || buf.readUInt32LE(8) !== buf.length) return false;
  let offset = 12, document = null, chunks = 0;
  try {
    while (offset < buf.length) {
      if (++chunks > 1024 || offset + 8 > buf.length) return false;
      const length = buf.readUInt32LE(offset), type = buf.readUInt32LE(offset + 4);
      if (length % 4 || offset + 8 + length > buf.length) return false;
      if (chunks === 1 && type !== 0x4e4f534a) return false;
      if (type === 0x4e4f534a) {
        if (document !== null) return false;
        document = JSON.parse(buf.toString('utf8', offset + 8, offset + 8 + length));
      }
      offset += 8 + length;
    }
    return offset === buf.length && selfContainedGltf(document);
  } catch (_) { return false; }
}
function safeUrl(value) {
  if (typeof value !== 'string' || value.length > 2048) return null;
  try { const url = new URL(value); return url.protocol === 'https:' && !url.username && !url.password ? url.href : null; } catch { return null; }
}
function validateAttachment(input) {
  const { filename, file_data, file_url } = input;
  if (typeof filename !== 'string' || filename.length > 200 || /[\x00-\x1f\x7f/\\]/.test(filename)) throw Error('Arquivo inválido');
  if (Boolean(file_data) === Boolean(file_url)) throw Error('Informe dados ou URL');
  if (file_url) {
    const url = safeUrl(file_url);
    if (!url) throw Error('URL inválida');
    return { filename, file_url: url, file_data: null, mime_type: 'application/octet-stream', size: null };
  }
  if (typeof file_data !== 'string' || file_data.length > Math.ceil(MAX_BYTES / 3) * 4 + 200) throw Error('Arquivo excede limite');
  const raw = file_data.startsWith('data:') ? file_data.slice(file_data.indexOf(',') + 1) : file_data;
  if (!validBase64(raw)) throw Error('Base64 inválido');
  const buf = Buffer.from(raw, 'base64');
  if (!buf.length || buf.length > MAX_BYTES) throw Error('Tamanho inválido');
  const ext = path.extname(filename).toLowerCase();
  const text = buf.toString('utf8');
  let mime = 'application/octet-stream', valid = false;
  switch (ext) {
    case '.pdf': mime = 'application/pdf'; valid = text.startsWith('%PDF-'); break;
    case '.png': mime = 'image/png'; valid = buf.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])); break;
    case '.jpg': case '.jpeg': mime = 'image/jpeg'; valid = buf[0]===255 && buf[1]===216 && buf[2]===255; break;
    case '.webp': mime='image/webp'; valid=text.startsWith('RIFF') && text.slice(8,12)==='WEBP'; break;
    case '.glb': mime='model/gltf-binary'; valid=selfContainedGlb(buf); break;
    case '.gltf':
      mime='model/gltf+json';
      // GLB and text glTF share the same no-external-resource policy.
      try { valid=selfContainedGltf(JSON.parse(text)); } catch {} break;
    case '.stl': valid=(buf.length>=84 && 84+buf.readUInt32LE(80)*50===buf.length) || (/^\s*solid\b/i.test(text) && /\bendsolid\b/i.test(text) && /\bfacet\s+normal\b/i.test(text)); break;
    case '.obj': valid=/^v\s+-?[\d.]+\s+-?[\d.]+\s+-?[\d.]+/m.test(text) && !/<|\x00/.test(text); break;
    case '.mtl': valid=/^newmtl\s+\S+/m.test(text) && !/<|\x00/.test(text); break;
    case '.3ds': valid=buf.length>=6 && buf.readUInt16LE(0)===0x4d4d && buf.readUInt32LE(2)===buf.length; break;
    case '.dwg': valid=/^AC10\d{2}/.test(text); break;
    case '.dxf': valid=/^\s*0\s*\r?\nSECTION\s*\r?\n/m.test(text) && /\r?\nEOF\s*$/.test(text); break;
    case '.step': case '.stp': valid=/^\s*ISO-10303-21;/.test(text) && /END-ISO-10303-21;\s*$/.test(text); break;
    case '.iges': case '.igs': valid=/^.{72}S\s*1\s*$/m.test(text) && /^.{72}T\s*1\s*$/m.test(text); break;
  }
  if (!valid) throw Error('Tipo ou conteúdo não permitido');
  return { filename, mime_type: mime, file_data: raw, file_url: null, size: Math.ceil(buf.length/1024) };
}
module.exports = { validateAttachment, safeUrl, MAX_BYTES };
