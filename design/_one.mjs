import { readFileSync, writeFileSync } from 'node:fs';
const f = process.argv[2], s = Number(process.argv[3] || 2);
const src = readFileSync(f, 'utf8');
const style = (src.match(/<helmet>\s*<style>([\s\S]*?)<\/style>/) || [,''])[1];
const W = Number(process.argv[4] || 375), H = Number(process.argv[5] || 812);
let bodyHtml = (src.match(/<\/helmet>([\s\S]*?)<\/x-dc>/) || [,''])[1].replace(/\{\{\s*accent\s*\}\}/g, '#FF5A3D');
writeFileSync('_one.html', `<!doctype html><meta charset="utf-8"><style>
html,body{margin:0;background:#8E8E88;}
.box{width:${W*s}px;height:${H*s}px;overflow:hidden}
.z{transform:scale(${s});transform-origin:0 0;width:${W}px;height:${H}px}
${style.replace(/(^|\})\s*body\s*\{[^}]*\}/g,'$1')}</style><div class="box"><div class="z">${bodyHtml}</div></div>`);
console.log('ok', f);
