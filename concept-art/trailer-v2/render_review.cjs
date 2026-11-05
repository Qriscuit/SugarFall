// Native-browser composition of the unmodified pose PNGs and review pages.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base=__dirname;
const root=path.resolve(base,'../..');
const evidence=path.join(root,'outputs/mabel-rethink-20261104/review');
const selected=JSON.parse(fs.readFileSync(path.join(root,'outputs/mabel-rethink-20261104/selected-catches.json'),'utf8'));
const {placement:initialLayout,...measured}=selected;
const compact={...measured,recommended:selected.recommended.map(({path:trajectory,...item})=>item),
 proposed_plate_surface_y:1526,initial_layout_targets:initialLayout,
 placement_note:'Initial source targets are retained as history. Current motion surface target1526 accounts for the radius below each recorded ball center. V2 uses painted pose registration and carried-food layers; final source-ball clean-pass verification is recorded separately.'};
if(compact.alternative_third?.path)delete compact.alternative_third.path;
fs.mkdirSync(path.join(base,'planning'),{recursive:true});
fs.mkdirSync(evidence,{recursive:true});
fs.writeFileSync(path.join(base,'planning/selected-catches.json'),JSON.stringify(compact,null,2)+'\n');
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu']});
 try{
  const page=await browser.newPage({viewport:{width:1600,height:1650},deviceScaleFactor:1});
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  const ready=async()=>{await page.evaluate(()=>document.fonts.ready);await page.waitForFunction(()=>Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0));};
  await page.goto(pathToFileURL(path.join(base,'mabel-painted/poses.html')).href);await ready();
  await page.screenshot({path:path.join(base,'mabel-painted/contact-sheet.png'),fullPage:true});
  await page.setViewportSize({width:1120,height:1100});
  await page.goto(pathToFileURL(path.join(base,'planning/catch-layout.html')).href);await ready();
  await page.screenshot({path:path.join(base,'planning/catch-layout.png'),fullPage:true});
  await page.setViewportSize({width:1360,height:1800});
  await page.goto(pathToFileURL(path.join(base,'review.html')).href);await ready();
  const desktopOverflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
  const loaded=await page.evaluate(()=>Array.from(document.images).map(i=>({src:i.getAttribute('src'),width:i.naturalWidth,height:i.naturalHeight})));
  await page.screenshot({path:path.join(evidence,'review-desktop.png'),fullPage:true});
  await page.setViewportSize({width:390,height:844});
  const mobileOverflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
  await page.screenshot({path:path.join(evidence,'review-mobile.png'),fullPage:true});
  await page.screenshot({path:path.join(evidence,'review-mobile-top.png')});
  await page.locator('section[aria-labelledby="ending-title"]').scrollIntoViewIfNeeded();
  await page.screenshot({path:path.join(evidence,'review-mobile-ending.png')});
  const missing=[];
  const hrefs=await page.locator('a').evaluateAll(nodes=>nodes.map(a=>a.getAttribute('href')));
  for(const href of hrefs.filter(h=>h&&!/^(https?:|#|mailto:)/.test(h)))if(!fs.existsSync(path.resolve(base,href)))missing.push(href);
  if(errors.length||desktopOverflow||mobileOverflow||missing.length)throw Error(JSON.stringify({errors,desktopOverflow,mobileOverflow,missing}));
  const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const result={passed:true,date:'2026-11-04',scope:'Artwork and historical planning review accompanying V2 painted stop-motion; final source-ball clean-pass and encoded-video verification tracked separately',images:loaded,console_errors:errors,desktop_overflow:desktopOverflow,mobile_overflow:mobileOverflow,local_links_checked:hrefs.length,missing_links:missing,contact_sheet_sha256:hash(path.join(base,'mabel-painted/contact-sheet.png')),catch_proof_sha256:hash(path.join(base,'planning/catch-layout.png'))};
  fs.writeFileSync(path.join(evidence,'page-validation.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result,null,2));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
