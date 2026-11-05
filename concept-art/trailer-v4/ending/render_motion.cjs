const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../../..'),out=path.join(root,'outputs/trailer-v4-20261104/ending');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu','--allow-file-access-from-files']});
 try{
 const page=await browser.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(pathToFileURL(path.join(__dirname,'motion.html')).href);await page.evaluate(()=>window.endingReady);const samples=[];
 for(let frame=0;frame<174;frame++){
  const state=await page.evaluate(t=>window.renderEnding(t),frame/60);
  if(frame===0){const sum=await page.evaluate(()=>{const p=document.querySelector('canvas').getContext('2d').getImageData(0,0,1080,1920).data;let n=0;for(let i=3;i<p.length;i+=4)n+=p[i];return n});if(sum!==0)throw Error('Ending must start with a transparent frame before its background fades in');}
  // Canvas PNG export retains RGBA for opaque and transparent frames alike.
  // A changing screenshot pixel format can make FFmpeg restart setpts mid-sequence.
  const png=await page.evaluate(()=>document.querySelector('canvas').toDataURL('image/png').split(',')[1]);
  fs.writeFileSync(path.join(out,'frame_'+String(frame).padStart(5,'0')+'.png'),Buffer.from(png,'base64'));
  if([0,12,24,36,50,60,69,90,173].includes(frame))samples.push({frame,...state});
  if(frame%30===0)console.log('ENDING_FRAME '+frame);
 }
 if(errors.length)throw Error(JSON.stringify(errors));
 const hash=f=>crypto.createHash('sha256').update(fs.readFileSync(path.join(out,f))).digest('hex');
 const result={passed:true,date:'2026-11-04',dimensions:[1080,1920],fps:60,frames:174,seconds:2.9,png_mode:'RGBA throughout; native canvas PNG export',edit_range:[27.1,30],pattern:'frame_%05d.png',generated_png_lettering:true,first_frame_transparent:true,final_hold:[1.15,2.9],hold_pixel_stable:hash('frame_00090.png')===hash('frame_00173.png'),layer_arrivals:{background:[0,.24],title:[.12,.42],food:[.35,.68],mabel:[.62,.95],cta:[.90,1.15]},samples,console_errors:errors,assets:await page.evaluate(()=>window.assetInfo)};
 if(!result.hold_pixel_stable)throw Error('Final hold moved');
 fs.writeFileSync(path.join(out,'render-validation.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({passed:true,frames:174,hold_pixel_stable:result.hold_pixel_stable,output:out}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
