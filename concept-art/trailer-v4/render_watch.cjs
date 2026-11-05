const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'outputs/trailer-v4-20261104/qa');
fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu']});
 try{
 const page=await browser.newPage({viewport:{width:1360,height:1000},deviceScaleFactor:1});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(pathToFileURL(path.join(__dirname,'watch.html')).href);
 await page.evaluate(()=>document.fonts.ready);
 await page.waitForFunction(()=>document.querySelector('video').readyState>=2&&Array.from(document.images).every(i=>i.complete&&i.naturalWidth));
 const metadata=await page.evaluate(()=>{const v=document.querySelector('video');return{width:v.videoWidth,height:v.videoHeight,duration:v.duration,readyState:v.readyState}});
 const seek=async time=>{await page.evaluate(t=>new Promise((resolve,reject)=>{const v=document.querySelector('video');v.pause();v.addEventListener('seeked',resolve,{once:true});v.addEventListener('error',()=>reject(Error('Video decode error')),{once:true});v.currentTime=t;}),time);await page.waitForFunction(()=>!document.querySelector('video').seeking&&document.querySelector('video').readyState>=2);await page.waitForTimeout(400);};
 await seek(12.9);
 const desktopOverflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
 await page.screenshot({path:path.join(out,'watch-desktop.png'),fullPage:true});
 await page.setViewportSize({width:390,height:844});
 const mobileOverflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
 await page.screenshot({path:path.join(out,'watch-mobile.png'),fullPage:true});
 await seek(29.983333);await page.locator('video').screenshot({path:path.join(out,'watch-ending.png')});
 await page.locator('button[data-time="10.816667"]').click();await page.waitForTimeout(120);
 const buttonTime=await page.evaluate(()=>{const v=document.querySelector('video');v.pause();return v.currentTime});
 const missing=[];for(const href of await page.locator('a').evaluateAll(a=>a.map(x=>x.getAttribute('href'))))if(!fs.existsSync(path.resolve(__dirname,href)))missing.push(href);
 if(errors.length||desktopOverflow||mobileOverflow||missing.length||metadata.duration!==30||metadata.width!==1080||buttonTime<10.8||buttonTime>11.6)throw Error(JSON.stringify({errors,desktopOverflow,mobileOverflow,missing,metadata,buttonTime}));
 const videoPath=path.join(root,'outputs/trailer-v4-20261104/Sugarfall-Trailer-V4-Review.mp4');
 const result={passed:true,video_sha256:crypto.createHash('sha256').update(fs.readFileSync(videoPath)).digest('hex'),metadata,console_errors:errors,desktop_overflow:desktopOverflow,mobile_overflow:mobileOverflow,missing_links:missing,jump_button_actual_time:buttonTime,phone_acceptance:false};
 fs.writeFileSync(path.join(out,'watch-validation.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
