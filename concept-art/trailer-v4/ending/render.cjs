const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../../..'),out=path.join(root,'outputs/trailer-v4-20261104/ending');
const exported=path.join(__dirname,'exports');fs.mkdirSync(out,{recursive:true});fs.mkdirSync(exported,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu','--allow-file-access-from-files']});
 try{
 const page=await browser.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(pathToFileURL(path.join(__dirname,'layout.html')).href);await page.evaluate(()=>window.endingReady);
 const results=[];
 for(const [mode,name,viewport] of [['portrait','sugarfall-end-card.png',{width:1080,height:1920}],['lockup','sugarfall-logo-lockup.png',{width:1920,height:1080}],['portrait-lockup','sugarfall-portrait-lockup.png',{width:1080,height:1920}],['wide','sugarfall-banner.png',{width:1920,height:1080}]]){
  await page.setViewportSize(viewport);const state=await page.evaluate(m=>window.renderEnding(2.9,m),mode);
  const target=path.join(exported,name);const png=await page.evaluate(()=>document.querySelector('canvas').toDataURL('image/png').split(',')[1]);fs.writeFileSync(target,Buffer.from(png,'base64'));
  results.push({file:path.relative(root,target).replaceAll('\\','/'),...state,sha256:crypto.createHash('sha256').update(fs.readFileSync(target)).digest('hex')});
 }
 if(errors.length)throw Error(JSON.stringify(errors));
 const result={passed:true,date:'2026-11-04',scope:'Native composition of Imagegen artwork; no generated lettering replaced by browser text',assets:await page.evaluate(()=>window.assetInfo),outputs:results,console_errors:errors};
 fs.writeFileSync(path.join(out,'layout-validation.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
