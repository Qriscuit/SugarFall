const fs=require('node:fs'),path=require('node:path');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'outputs/storefront-20261105');
(async()=>{
  const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu','--allow-file-access-from-files']});
  try {
    const results=[];
    for(const [name,viewport] of [['desktop',{width:1360,height:1000}],['mobile',{width:390,height:844}]]){
      const page=await browser.newPage({viewport,deviceScaleFactor:1}),errors=[];
      page.on('pageerror',e=>errors.push(String(e)));
      await page.goto(pathToFileURL(path.join(out,'review.html')).href);
      await page.locator('footer').scrollIntoViewIfNeeded();
      await page.evaluate(()=>Promise.all([...document.images].map(im=>im.decode())));
      await page.evaluate(()=>window.scrollTo(0,0));
      const info=await page.evaluate(()=>({
        image_count:document.images.length,
        dimensions:[...document.images].map(i=>[i.naturalWidth,i.naturalHeight]),
        no_horizontal_overflow:document.documentElement.scrollWidth<=innerWidth,
        local_links:[...document.querySelectorAll('a[href]')].map(a=>a.getAttribute('href')),
      }));
      if(info.image_count!==8 || !info.no_horizontal_overflow || errors.length)throw Error(JSON.stringify({name,info,errors}));
      for(const href of info.local_links)if(!fs.existsSync(path.join(out,href)))throw Error('Broken link: '+href);
      await page.screenshot({path:path.join(out,'qa/review-'+name+'.png'),fullPage:true});
      results.push({name,viewport,passed:true,...info,errors});
      await page.close();
    }
    fs.writeFileSync(path.join(out,'qa/review-validation.json'),JSON.stringify({passed:true,date:'2026-11-05',results},null,2)+'\n');
    console.log(JSON.stringify({passed:true,viewports:results.map(r=>r.name),image_count:8,no_broken_links:true}));
  }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
