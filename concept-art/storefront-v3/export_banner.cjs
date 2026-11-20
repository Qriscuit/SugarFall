// Export sizing/encoding only. Creative artwork is the built-in Imagegen output.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const source = path.join(__dirname, 'source/banner-generated.png');
const target = path.join(__dirname, 'exports/sugarfall-feature-1024x500.png');
const ffmpeg = path.join(root, 'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe');
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
function info(p) {
  const b = fs.readFileSync(p);
  if (b.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') throw Error('Expected PNG: ' + p);
  return {width: b.readUInt32BE(16), height: b.readUInt32BE(20), bit_depth: b[24], color_type: b[25], bytes: b.length, sha256: hash(p)};
}
fs.mkdirSync(path.dirname(target), {recursive: true});
execFileSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-y', '-i', source, '-vf', 'scale=1024:500:flags=lanczos', '-frames:v', '1', '-pix_fmt', 'rgb24', '-compression_level', '9', target], {stdio: 'inherit'});
const report = {
  date: '2026-11-05', tool: 'Built-in image_gen.imagegen',
  prompt: 'concept-art/storefront-v3/prompt.txt',
  reference: {...info(path.join(__dirname, 'source/banner-reference.png')), file: 'source/banner-reference.png'},
  generated_source: {...info(source), file: 'source/banner-generated.png'},
  export: {...info(target), file: 'exports/sugarfall-feature-1024x500.png'},
  processing: 'Lanczos reduction to the requested exact pixel size; lossless 24-bit RGB PNG encoding. No creative changes after generation.',
};
report.passed = report.export.width === 1024 && report.export.height === 500 && report.export.bit_depth === 8 && report.export.color_type === 2 && report.export.bytes < 15000000;
if (!report.passed) throw Error(JSON.stringify(report));
fs.writeFileSync(path.join(__dirname, 'banner-validation.json'), JSON.stringify(report, null, 2) + '\n');
const out = path.join(root, 'outputs/storefront-20261105');
fs.mkdirSync(out, {recursive: true});
fs.copyFileSync(target, path.join(out, path.basename(target)));
console.log(JSON.stringify(report, null, 2));
