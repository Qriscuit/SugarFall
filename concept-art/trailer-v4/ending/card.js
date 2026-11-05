/* Layered composition of the approved paintings. No source PNG is repainted. */
const canvas=document.getElementById('card'),ctx=canvas.getContext('2d');
const ASSETS={
 title:'../../trailer-v3/source/sugarfall-wordmark.png',
 food:'../../trailer-v3/source/food-collision-board.png',
 mabel:'../../trailer-v3/source/mabel-end.png',
 cta:'../../trailer-v3/source/play-now-button.png',
 baking:'../../../PLINKO/data/art/food/countertop.png',
 marble:'../../../PLINKO/data/art/gelato/food/countertop.png',
 flowers:'../../../PLINKO/data/art/arc_props/flower_planter.png'
};
const clamp=v=>Math.max(0,Math.min(1,v));
const ease=v=>{const p=clamp(v);return 1-Math.pow(1-p,3)};
const arrival=(t,start,end)=>ease((t-start)/(end-start));
const load=src=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=()=>reject(Error(src));im.src=src});
function alphaBounds(image){
 const c=document.createElement('canvas');c.width=image.width;c.height=image.height;
 const g=c.getContext('2d',{willReadFrequently:true});g.drawImage(image,0,0);const p=g.getImageData(0,0,c.width,c.height).data;
 let l=c.width,t=c.height,r=0,b=0;
 for(let y=0;y<c.height;y++)for(let x=0;x<c.width;x++)if(p[(y*c.width+x)*4+3]>12){l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y)}
 if(r<l||b<t)throw Error('Empty painting');const pad=3;l=Math.max(0,l-pad);t=Math.max(0,t-pad);r=Math.min(c.width-1,r+pad);b=Math.min(c.height-1,b+pad);return[l,t,r-l+1,b-t+1];
}
const loaded={};
window.endingReady=Promise.all(Object.entries(ASSETS).map(async([name,src])=>{
 const image=await load(src);loaded[name]={image,crop:['baking','marble'].includes(name)?[0,0,image.width,image.height]:alphaBounds(image)};
})).then(()=>{window.assetInfo=Object.fromEntries(Object.entries(loaded).map(([n,v])=>[n,{size:[v.image.width,v.image.height],crop:v.crop}]));return true;});
const PORTRAIT={title:[60,120,960,322],food:[30,445,1020,520],mabel:[40,975,620,890],cta:[550,1440,480,170]};
const WIDE={title:[85,70,1110,300],food:[20,370,1290,650],mabel:[1180,150,560,810],cta:[1510,935,350,115]};
function imageInBox(name,box,options={}){
 const{image,crop}=loaded[name],[sx,sy,sw,sh]=crop,[bx,by,bw,bh]=box,k=Math.min(bw/sw,bh/sh)*(options.scale??1);
 const w=sw*k,h=sh*k,x=bx+(bw-w)/2+(options.x??0),y=by+(bh-h)/2+(options.y??0);
 ctx.save();ctx.globalAlpha*=options.alpha??1;ctx.translate(x+w/2,y+h/2);ctx.rotate(options.rotation??0);ctx.drawImage(image,sx,sy,sw,sh,-w/2,-h/2,w,h);ctx.restore();return[x,y,w,h];
}
function cover(name,width,height,alpha){const{image}=loaded[name],k=Math.max(width/image.width,height/image.height);ctx.save();ctx.globalAlpha*=alpha;ctx.drawImage(image,(width-image.width*k)/2,(height-image.height*k)/2,image.width*k,image.height*k);ctx.restore();}
function background(width,height,alpha){
 ctx.save();ctx.globalAlpha=alpha;
 const base=ctx.createLinearGradient(0,0,width,height);base.addColorStop(0,'#cae1d5');base.addColorStop(.58,'#e3daea');base.addColorStop(1,'#bcded7');ctx.fillStyle=base;ctx.fillRect(0,0,width,height);
 cover('baking',width,height,.72);cover('marble',width,height,.13);
 const wash=ctx.createLinearGradient(0,0,width,height);wash.addColorStop(0,'#d7ede04d');wash.addColorStop(.55,'#eddfef70');wash.addColorStop(1,'#d3e9e459');ctx.fillStyle=wash;ctx.fillRect(0,0,width,height);
 const glow=ctx.createRadialGradient(width*.45,height*.28,0,width*.5,height*.40,height*.7);glow.addColorStop(0,'#fff9e672');glow.addColorStop(1,'#fff8e600');ctx.fillStyle=glow;ctx.fillRect(0,0,width,height);
 if(height>width)imageInBox('flowers',[890,1580,420,420],{alpha:.28});
 else imageInBox('flowers',[1770,745,340,340],{alpha:.24});
 ctx.restore();
}
window.renderEnding=function(seconds=2.9,mode='portrait'){
 const t=clamp(Number(seconds)/2.9)*2.9,wide=mode==='wide'||mode==='lockup',lockup=mode==='lockup'||mode==='portrait-lockup';
 const width=wide?1920:1080,height=wide?1080:1920;if(canvas.width!==width||canvas.height!==height){canvas.width=width;canvas.height=height;}
 ctx.clearRect(0,0,width,height);const bgIn=arrival(t,0,.24);if(!lockup)background(width,height,bgIn);
 const titleIn=arrival(t,.12,.42),foodIn=arrival(t,.35,.68),mabelIn=arrival(t,.62,.95),ctaIn=arrival(t,.90,1.15),boxes=wide?WIDE:PORTRAIT;
 const food=imageInBox('food',boxes.food,{alpha:foodIn,x:-20*(1-foodIn),y:48*(1-foodIn),scale:.97+.03*foodIn});
 const title=imageInBox('title',boxes.title,{alpha:titleIn,y:-28*(1-titleIn),scale:.97+.03*titleIn});
 const mabel=imageInBox('mabel',boxes.mabel,{alpha:mabelIn,x:-42*(1-mabelIn)});
 const cta=lockup?null:imageInBox('cta',boxes.cta,{alpha:ctaIn,y:24*(1-ctaIn),scale:.96+.04*ctaIn});
 const state={time:t,mode,dimensions:[width,height],title,food,mabel,cta,opacity:{background:bgIn,title:titleIn,food:foodIn,mabel:mabelIn,cta:ctaIn},finalHold:t>=1.15};window.endingState=state;return state;
};
