const fs=require('node:fs'),path=require('node:path');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../../..'),out=path.join(root,'outputs/trailer-v4-20261104/ending');
(async()=>{const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu']});try{const page=await browser.newPage({viewport:{width:1400,height:1550},deviceScaleFactor:1});await page.goto(pathToFileURL(path.join(__dirname,'stagger-review.html')).href);await page.waitForFunction(()=>Array.from(document.images).every(i=>i.complete&&i.naturalWidth));await page.screenshot({path:path.join(out,'stagger-review.png'),fullPage:true});console.log('Stagger proof rendered');}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
