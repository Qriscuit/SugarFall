const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base=__dirname;
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu']});
 try{
  const page=await browser.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  const records=[];
  for(const concept of ['catch','tray']){
   await page.goto(pathToFileURL(path.join(base,'preview.html')).href+'?concept='+concept);
   const font=await page.evaluate(()=>window.fontReady);
   await page.waitForFunction(()=>Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0));
   if(!font.loaded||font.faces!==1)throw Error('Bundled Fraunces did not load');
   const geometry=await page.locator('.option-'+(concept==='catch'?'a':'b')+' .wordmark').evaluate(el=>({rect:el.getBoundingClientRect().toJSON(),family:getComputedStyle(el).fontFamily,axes:getComputedStyle(el).fontVariationSettings}));
   const file=path.join(base,'ending-'+concept+'.png');
   await page.screenshot({path:file});
   records.push({concept,png:path.basename(file),font,geometry,sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')});
  }
  await page.setViewportSize({width:1160,height:1130});
  await page.goto(pathToFileURL(path.join(base,'preview.html')).href);
  await page.evaluate(()=>window.fontReady);
  await page.waitForFunction(()=>Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0));
  await page.screenshot({path:path.join(base,'contact-sheet.png'),fullPage:true});
  if(errors.length)throw Error(errors.join('\n'));
  const fontFile=path.resolve(base,'../../../PLINKO/data/fonts/Fraunces-Variable.ttf');
  fs.writeFileSync(path.join(base,'validation.json'),JSON.stringify({passed:true,date:'2026-11-04',scope:'End composition stills only; V1 movie untouched',dimensions:[1080,1920],font_source:'PLINKO/data/fonts/Fraunces-Variable.ttf',font_sha256:crypto.createHash('sha256').update(fs.readFileSync(fontFile)).digest('hex'),axes:{wght:650,SOFT:70,opsz:36,WONK:1},engine:'Microsoft Edge / Chromium',console_errors:errors,concepts:records},null,2)+'\n');
  console.log('Ending concepts rendered with verified Fraunces');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
