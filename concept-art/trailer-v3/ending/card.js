/* Native composition of the generated PNG layers. Source assets stay unchanged. */
const canvas=document.getElementById('card');
const ctx=canvas.getContext('2d');
const ASSETS={
 title:'../source/sugarfall-wordmark.png',
 food:'../source/food-collision-board.png',
 mabel:'../source/mabel-end.png',
 cta:'../source/play-now-button.png',
 marble:'../../../PLINKO/data/art/gelato/food/countertop.png'
};
const clamp=value=>Math.max(0,Math.min(1,value));
const smooth=value=>{const v=clamp(value);return v*v*(3-2*v)};
function loadImage(src){return new Promise((resolve,reject)=>{const image=new Image();image.onload=()=>resolve(image);image.onerror=()=>reject(Error('Missing image: '+src));image.src=src})}
function alphaBounds(image){
 const c=document.createElement('canvas');c.width=image.width;c.height=image.height;
 const g=c.getContext('2d',{willReadFrequently:true});g.drawImage(image,0,0);
 const pixels=g.getImageData(0,0,c.width,c.height).data;
 let l=c.width,t=c.height,r=0,b=0;
 for(let y=0;y<c.height;y++)for(let x=0;x<c.width;x++)if(pixels[(y*c.width+x)*4+3]>12){l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y)}
 if(r<l||b<t)throw Error('Empty generated PNG: '+image.src);
 const pad=3;l=Math.max(0,l-pad);t=Math.max(0,t-pad);r=Math.min(c.width-1,r+pad);b=Math.min(c.height-1,b+pad);
 return [l,t,r-l+1,b-t+1];
}
const loaded={};
window.endingReady=Promise.all(Object.entries(ASSETS).map(async([name,src])=>{
 const image=await loadImage(src);loaded[name]={image,crop:name==='marble'?[0,0,image.width,image.height]:alphaBounds(image)};
})).then(()=>{window.assetInfo=Object.fromEntries(Object.entries(loaded).map(([n,v])=>[n,{size:[v.image.width,v.image.height],crop:v.crop}]));return true});
const PORTRAIT={
 title:[60,135,960,355],food:[30,505,1020,720],mabel:[65,1080,560,770],cta:[610,1440,410,150]
};
const WIDE={
 title:[85,88,1110,300],food:[20,405,1290,615],mabel:[1180,170,560,790],cta:[1510,935,350,115]
};
function imageInBox(name,box,options={}){
 const {image,crop}=loaded[name], [sx,sy,sw,sh]=crop;
 const [bx,by,bw,bh]=box;const k=Math.min(bw/sw,bh/sh)*(options.scale??1);
 const w=sw*k,h=sh*k,x=bx+(bw-w)/2+(options.x??0),y=by+(bh-h)/2+(options.y??0);
 ctx.save();ctx.globalAlpha=options.alpha??1;ctx.translate(x+w/2,y+h/2);ctx.rotate(options.rotation??0);
 ctx.drawImage(image,sx,sy,sw,sh,-w/2,-h/2,w,h);ctx.restore();return [x,y,w,h];
}
function background(width,height){
 const grad=ctx.createLinearGradient(0,0,width,height);grad.addColorStop(0,'#cfe4d9');grad.addColorStop(.55,'#e2dcee');grad.addColorStop(1,'#c2e3de');ctx.fillStyle=grad;ctx.fillRect(0,0,width,height);
 const {image}=loaded.marble,k=Math.max(width/image.width,height/image.height);ctx.globalAlpha=.22;ctx.drawImage(image,(width-image.width*k)/2,(height-image.height*k)/2,image.width*k,image.height*k);ctx.globalAlpha=1;
 const glow=ctx.createRadialGradient(width*.4,height*.35,10,width*.5,height*.4,height*.6);glow.addColorStop(0,'#fffae85c');glow.addColorStop(1,'#fff8e600');ctx.fillStyle=glow;ctx.fillRect(0,0,width,height);
}
window.renderEnding=function(seconds=2.9,mode='portrait'){
 const t=clamp(Number(seconds)/2.9)*2.9,wide=mode==='wide'||mode==='lockup',lockup=mode==='lockup'||mode==='portrait-lockup';
 const width=wide?1920:1080,height=wide?1080:1920;
 if(canvas.width!==width||canvas.height!==height){canvas.width=width;canvas.height=height;}
 ctx.clearRect(0,0,width,height);if(!lockup)background(width,height);
 const boxes=wide?WIDE:PORTRAIT;
 const titleIn=smooth(t/.46),foodIn=smooth((t-.08)/.45),mabelIn=smooth((t-.20)/.40),ctaIn=smooth((t-.58)/.25);
 const pulse=t>=.28&&t<.64?Math.sin((t-.28)/.36*Math.PI):0;
 const food=imageInBox('food',boxes.food,{alpha:foodIn,y:22*(1-foodIn),scale:.975+.025*foodIn+.008*pulse});
 const title=imageInBox('title',boxes.title,{alpha:titleIn,y:-15*(1-titleIn),scale:.99+.01*titleIn});
 const mabel=imageInBox('mabel',boxes.mabel,{alpha:mabelIn,x:28*(1-mabelIn)});
 const cta=lockup?null:imageInBox('cta',boxes.cta,{alpha:ctaIn,y:8*(1-ctaIn),scale:.99+.01*ctaIn});
 const state={time:t,mode,dimensions:[width,height],title,food,mabel,cta,opacity:{title:titleIn,food:foodIn,mabel:mabelIn,cta:ctaIn},finalHold:t>=.83};
 window.endingState=state;return state;
};
