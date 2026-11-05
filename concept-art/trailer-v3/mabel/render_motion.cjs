const fs=require('node:fs'),path=require('node:path');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../../..');
const out=path.join(root,'outputs/trailer-v3-20261104/mabel');
fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu','--allow-file-access-from-files']});
 try{
 const page=await browser.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(pathToFileURL(path.join(__dirname,'motion.html')).href);await page.evaluate(()=>window.ready);
 const states=[];
 for(let frame=0;frame<373;frame++){
  states.push(await page.evaluate(f=>window.renderFrame(f),frame));
  await page.screenshot({path:path.join(out,'frame_'+String(frame).padStart(5,'0')+'.png'),omitBackground:true});
  if(frame%60===0)console.log('Mabel '+frame+'/373');
 }
 if(errors.length)throw Error(JSON.stringify(errors));
 fs.writeFileSync(path.join(out,'frame-states.json'),JSON.stringify({fps:60,frames:373,edit_range:[14.4,20.6166667],greeting_hold:[15.10,15.95],twin_source_frames:[155,420],style:'Painted cutout stop-motion with a still greeting hold; original catch response and separate carried food remain60fps',states,errors},null,2)+'\n');
 console.log('Mabel overlay complete: '+out);
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
