// Package the exact banner export and native screenshots for local review.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const out = path.join(root, 'outputs/storefront-20261105');
const shotDir = path.join(out, 'screenshots');
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const specs = [
  ['01-bakery-gameplay.png', 'Bakery gameplay', 'Doughnuts, cookie pegs and collecting cups.', 'Doughnuts hit silver cookie pegs above five collecting cups in Bakery.'],
  ['02-gelato-aim.png', 'Aim with gravity', 'Gelato with its curved aim preview.', 'Gelato ice cream follows a curved dotted aim preview toward waffle pegs.'],
  ['03-crystal-prism.png', 'Crystal gameplay', 'Straight shots and a live timed ×2 pickup.', 'Crystal candy ricochets through pegs beside a floating timed ×2 pickup.'],
  ['04-gelato-upgrades.png', 'Choose upgrades', 'The current branching Gelato upgrade map.', 'Gelato upgrades branch across a ceramic garden map with owned and available nodes.'],
  ['05-bakery-jam.png', 'Jam Burst', 'An earned Jam Burst hit between cookie pegs.', 'A Jam Burst hit links gold cookie pegs while doughnuts fall through Bakery.'],
  ['06-gelato-twins.png', 'Twin launchers', 'Two launchers with separate dotted previews.', 'Two Gelato launchers show dotted aim paths above ice cream and gold waffle pegs.'],
  ['07-crystal-multiply.png', 'Multiply candy', 'Immediately after a real ×2 pickup doubles five live balls to ten.', 'Ten live candy balls appear after collecting Crystal’s ×2 pickup.'],
];
function png(p) {
  const b = fs.readFileSync(p);
  if (b.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') throw Error('Invalid PNG: ' + p);
  return {width: b.readUInt32BE(16), height: b.readUInt32BE(20), bit_depth: b[24], png_color_type: b[25], bytes: b.length, sha256: hash(p)};
}
const screenshots = specs.map(([file,title,description,alt],i) => ({order:i+1, file:'screenshots/'+file, title, description, alt, ...png(path.join(shotDir,file))}));
if (screenshots.length !== 7 || screenshots.some(s=>s.width!==1080 || s.height!==1920 || s.bit_depth!==8 || s.png_color_type!==2)) throw Error('Screenshot requirements failed');
const banner = {file:'sugarfall-feature-1024x500.png', ...png(path.join(out,'sugarfall-feature-1024x500.png'))};
if (banner.width!==1024 || banner.height!==500 || banner.bytes>=15000000 || banner.png_color_type!==2 || banner.bit_depth!==8) throw Error('Banner requirements failed');
const manifest = {
  date:'2026-11-05', screenshot_count:7, banner,
  screenshots,
  screenshots_provenance:'Actual uncomposited current-workspace game renderer, nondebug public Windows export. Progress and wallets staged in isolated memory; normal physics and earned-ability APIs. Zero player-profile IO.',
  banner_provenance:'Built-in Imagegen adaptation of the supplied banner. Exact-size Lanczos reduction and RGB PNG encoding only after generation.',
  evidence:['screenshots/capture-report.json','screenshots/source-evidence.json','screenshots/screenshots-validation.json','qa/independent-screenshots-review.json','qa/independent-banner-review.json'],
  physical_android_verified:false,
  distribution:'Local deliverables. No store or Drive upload.',
};
const esc = s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const cards = screenshots.map(s=>`<article><a class="image-link" href="${s.file}" target="_blank"><img src="${s.file}" alt="${esc(s.alt)}" width="1080" height="1920" loading="lazy"></a><div class="caption"><h2>${s.order}. ${esc(s.title)}</h2><p>${esc(s.description)}</p><a download href="${s.file}">Download PNG · ${(s.bytes/1000000).toFixed(2)} MB</a></div></article>`).join('\n');
const html = `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Sugarfall store assets · 5 November 2026</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#eff5f1;color:#203b36;font:16px/1.5 system-ui,sans-serif}main{max-width:1280px;margin:0 auto;padding:28px 22px 60px}h1{font-size:clamp(24px,4vw,36px);margin:0 0 10px}h2{font-size:18px;margin:0 0 7px}p{margin:0 0 14px}a{color:#075e51}header{max-width:820px;margin-bottom:26px}.download{display:inline-block;padding:11px 18px;border-radius:9px;background:#145b4b;color:#fff;text-decoration:none;font-weight:650;margin:4px 0 12px}.banner{padding:18px;background:white;border:1px solid #d4dfd8;border-radius:14px;margin-bottom:28px}.banner img{width:100%;height:auto;display:block;border-radius:6px}.banner figcaption{padding-top:12px}.banner figure{margin:0}.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:20px}article{overflow:hidden;border:1px solid #d4dfd8;border-radius:12px;background:white}.image-link{display:block;background:#d9e6df}.image-link img{display:block;width:100%;height:auto}.caption{padding:14px}.caption p{font-size:14px}.caption a{font-size:14px}footer{margin-top:28px;max-width:920px;color:#466159;font-size:14px}a:focus-visible{outline:3px solid #bc620a;outline-offset:4px}@media(max-width:980px){.grid{grid-template-columns:repeat(3,minmax(0,1fr))}}@media(max-width:680px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}main{padding:20px 14px}.caption{padding:11px}}@media(max-width:380px){.grid{grid-template-columns:1fr}}
</style><main><header><h1>Sugarfall store assets</h1><p>Seven game screenshots and the Mabel banner at exactly 1024 × 500. Click any image to inspect the full PNG.</p><a class="download" download href="Sugarfall-Store-Assets-20261105.zip">Download all 8 images</a><p>All screenshots are 1080 × 1920. The banner is ${(banner.bytes/1000000).toFixed(2)} MB.</p></header>
<section class="banner"><figure><a href="${banner.file}" target="_blank"><img src="${banner.file}" width="1024" height="500" alt="Sugarfall title above a mint ceramic tray with bouncing sweets, with Mabel presenting the tray on the right."></a><figcaption><a download href="${banner.file}">Download banner PNG · 1024 × 500 · ${(banner.bytes/1000000).toFixed(2)} MB</a></figcaption></figure></section>
<section class="grid" aria-label="Seven game screenshots">${cards}</section>
<footer><p>These screenshots use the current game’s Windows renderer with staged progress, normal gameplay rules and no captions or compositing. They have not been captured or verified on a physical Android phone. The banner is promotional illustration made with Imagegen from your reference.</p><p><a href="manifest.json">File details and hashes</a> · <a href="screenshots/capture-report.json">Capture evidence</a></p></footer></main></html>`;
fs.writeFileSync(path.join(out,'review.html'),html);
fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
fs.writeFileSync(path.join(out,'README.txt'),`Sugarfall store assets — 5 November 2026\n\nBanner: ${banner.file},1024x500,RGB PNG,${banner.bytes} bytes.\nScreenshots:7 PNG files,1080x1920 each,in screenshots/.\nReview:open review.html in a browser.\n\n${manifest.screenshots_provenance}\nPhysical Android appearance still needs comparison before submission.\n${manifest.distribution}\n\n${screenshots.map(s=>s.order+'. '+s.file+' — '+s.title).join('\n')}\n`);
console.log(JSON.stringify({banner,screenshot_count:screenshots.length,bytes_images:banner.bytes+screenshots.reduce((a,s)=>a+s.bytes,0),review:'outputs/storefront-20261105/review.html'},null,2));
