import { readFileSync, writeFileSync } from 'node:fs';
const files = process.argv.slice(2);
let out = `<!doctype html><meta charset="utf-8"><style>
body{margin:0;background:#8E8E88;padding:40px;display:flex;gap:40px;align-items:flex-start;font-family:-apple-system,sans-serif}
.wrap{display:flex;flex-direction:column;gap:10px}
.lbl{font:600 13px -apple-system;color:#fff;letter-spacing:.3px}
.hold{outline:1px solid rgba(255,255,255,.35)}
</style>`;
for (const f of files) {
  const src = readFileSync(f, 'utf8');
  const style = (src.match(/<helmet>\s*<style>([\s\S]*?)<\/style>/) || [,''])[1];
  let bodyHtml = (src.match(/<\/helmet>([\s\S]*?)<\/x-dc>/) || [,''])[1];
  bodyHtml = bodyHtml.replace(/\{\{\s*accent\s*\}\}/g, '#FF5A3D');
  out += `<div class="wrap"><div class="lbl">${f}</div><div class="hold"><style>${style.replace(/(^|\})\s*body\s*\{[^}]*\}/g,'$1')}</style>${bodyHtml}</div></div>`;
}
writeFileSync('_preview.html', out);
console.log('ok', files.length);
