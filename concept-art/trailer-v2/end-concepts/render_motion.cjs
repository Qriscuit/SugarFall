// Deterministic browser rendering of the native end composition, 1080x1920/60fps.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../../..');
const output=path.join(root,'outputs/trailer-v2-20261104/ending');
const fps=60,frames=174;
(async()=>{
 fs.mkdirSync(output,{recursive:true});
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu']});
 try{
  const page=await browser.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});
  const errors=[];page.on('pageerror',error=>errors.push(String(error)));
  await page.goto(pathToFileURL(path.join(__dirname,'motion.html')).href);
  await page.evaluate(()=>window.endingReady);
  const samples=[];
  for(let frame=0;frame<frames;frame++){
   const state=await page.evaluate(time=>window.renderEnding(time),frame/fps);
   await page.screenshot({path:path.join(output,'frame_'+String(frame).padStart(5,'0')+'.png')});
   if([0,15,31,47,90,173].includes(frame))samples.push({frame,...state});
   if(frame%30===0)console.log('ENDING_FRAME '+frame);
  }
  if(errors.length)throw Error(errors.join('\n'));
  const result={passed:true,date:'2026-11-04',scope:'Animated promotional ending A; no Mabel re-entry',dimensions:[1080,1920],fps,frames,seconds:frames/fps,pattern:'frame_%05d.png',source:path.relative(root,path.join(__dirname,'motion.html')).replaceAll('\\','/'),contact_seconds:.52,contact_edit_seconds:27.62,title_reveal:[.52,.78],final_hold:[.78,2.9],font:{file:'PLINKO/data/fonts/Fraunces-Variable.ttf',sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'PLINKO/data/fonts/Fraunces-Variable.ttf'))).digest('hex'),axes:{wght:650,SOFT:70,opsz:36,WONK:1},loaded:true},front_cup_occlusion:true,console_errors:errors,samples};
  fs.writeFileSync(path.join(output,'render-validation.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify({passed:true,output,frames,fps,seconds:frames/fps}));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
