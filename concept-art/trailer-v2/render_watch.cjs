const fs=require('node:fs'),path=require('node:path');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'outputs/trailer-v2-20261104/qa');
fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu']});
 try{
 const page=await browser.newPage({viewport:{width:1360,height:1000},deviceScaleFactor:1});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(pathToFileURL(path.join(__dirname,'watch.html')).href);
 await page.evaluate(()=>document.fonts.ready);
 await page.waitForFunction(()=>document.querySelector('video').readyState>=2&&Array.from(document.images).every(i=>i.complete&&i.naturalWidth));
 const metadata=await page.evaluate(()=>{const v=document.querySelector('video');return{width:v.videoWidth,height:v.videoHeight,duration:v.duration,readyState:v.readyState}});
 const seek=async time=>{await page.evaluate(t=>new Promise((resolve,reject)=>{const v=document.querySelector('video');v.pause();v.addEventListener('seeked',resolve,{once:true});v.addEventListener('error',()=>reject(Error('Video decode error')),{once:true});v.currentTime=t;}),time);await page.waitForTimeout(100);};
 await seek(18.966667);
 const desktopOverflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
 await page.screenshot({path:path.join(out,'watch-desktop.png'),fullPage:true});
 await page.setViewportSize({width:390,height:844});
 const mobileOverflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
 await page.screenshot({path:path.join(out,'watch-mobile.png'),fullPage:true});
 await seek(28.5);await page.locator('video').screenshot({path:path.join(out,'watch-ending.png')});
 await page.locator('button[data-time="16.2"]').click();await page.waitForTimeout(120);
 const buttonTime=await page.evaluate(()=>{const v=document.querySelector('video');v.pause();return v.currentTime});
 const missing=[];for(const href of await page.locator('a').evaluateAll(a=>a.map(x=>x.getAttribute('href'))))if(!fs.existsSync(path.resolve(__dirname,href)))missing.push(href);
 if(errors.length||desktopOverflow||mobileOverflow||missing.length||metadata.duration!==30||metadata.width!==1080||buttonTime<16.19||buttonTime>17)throw Error(JSON.stringify({errors,desktopOverflow,mobileOverflow,missing,metadata,buttonTime}));
 const result={passed:true,metadata,console_errors:errors,desktop_overflow:desktopOverflow,mobile_overflow:mobileOverflow,missing_links:missing,jump_button_actual_time:buttonTime,phone_acceptance:false};
 fs.writeFileSync(path.join(out,'watch-validation.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
