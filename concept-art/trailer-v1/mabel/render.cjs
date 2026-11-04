const fs=require('node:fs');
const path=require('node:path');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const base=__dirname;
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu']});
 try{
  const page=await browser.newPage({viewport:{width:600,height:1000},deviceScaleFactor:1});
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  for(const name of ['present','catch','catch-two','balance','balance-step','settle','puppet']){
   await page.goto(pathToFileURL(path.join(base,'render-one.html')).href+'?pose='+name);
   await page.waitForFunction(()=>document.images[0].complete&&document.images[0].naturalWidth===600);
   await page.screenshot({path:path.join(base,'mabel-'+name+'.png'),omitBackground:true});
  }
  await page.setViewportSize({width:140,height:110});
  await page.goto(pathToFileURL(path.join(base,'render-one.html')).href+'?pose=prop');
  await page.waitForFunction(()=>document.images[0].complete&&document.images[0].naturalWidth===140);
  await page.screenshot({path:path.join(base,'doughnut-prop.png'),omitBackground:true});
  await page.setViewportSize({width:1700,height:1120});
  await page.goto(pathToFileURL(path.join(base,'preview.html')).href);
  await page.waitForFunction(()=>Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0));
  await page.screenshot({path:path.join(base,'contact-sheet.png'),fullPage:true});
  if(errors.length)throw Error(errors.join('\n'));
  fs.writeFileSync(path.join(base,'render-verification.json'),JSON.stringify({passed:true,engine:'Microsoft Edge / Chromium',transparent_puppet_pngs:7,width:600,height:1000,prop_png:[140,110],console_errors:errors},null,2)+'\n');
  console.log('Mabel SVG renders passed');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
