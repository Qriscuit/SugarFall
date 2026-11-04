// Render the authored vector title transparently; no raster artwork is embedded.
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium} = require('C:/Users/Hursh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root = path.resolve(__dirname,'../../..');
const output = path.join(root,'outputs/trailer-v1-20261104/overlays');
(async()=>{
  fs.mkdirSync(output,{recursive:true});
  const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--disable-gpu','--in-process-gpu']});
  try {
    const page=await browser.newPage({viewport:{width:1080,height:300},deviceScaleFactor:1});
    await page.goto(pathToFileURL(path.join(__dirname,'title.svg')).href);
    await page.screenshot({path:path.join(output,'title.png'),omitBackground:true});
    console.log(JSON.stringify({file:path.join(output,'title.png'),width:1080,height:300}));
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
