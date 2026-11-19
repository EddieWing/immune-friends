/* Shared presentation-only connection gesture. No bond creation or physics here. */
const BondGesture=(()=>{
 const clamp=x=>Math.max(0,Math.min(1,x)),ease=x=>{x=clamp(x);return x*x*(3-2*x)};
 function state(seconds){let t=((seconds%6)+6)%6,release=1-ease((t-5)/1),reach=ease((t-1.4)/1.2)*release,grip=ease((t-2.4)/.35)*release;return {t,reach,grip,bulge:(9*ease(t/.7)+8*ease((t-.7)/.7)-7*ease((t-1.4)/1.2))*release,label:t<.7?'1 · Намерение: бугорок':t<1.4?'2 · Вытягивание':t<2.65?'3 · Ручки тянутся друг к другу':t<5?'4 · Захват и удержание':'5 · Возврат для повтора'}}
 function anchor(poly,origin,dir){let best=Infinity,out=origin;for(let i=0;i<poly.length;i++){let p=poly[i],q=poly[(i+1)%poly.length],sx=q[0]-p[0],sy=q[1]-p[1],den=dir[0]*sy-dir[1]*sx;if(Math.abs(den)<1e-7)continue;let px=p[0]-origin[0],py=p[1]-origin[1],t=(px*sy-py*sx)/den,u=(px*dir[1]-py*dir[0])/den;if(t>=0&&u>=-1e-9&&u<=1+1e-9&&t<best){best=t;out=[origin[0]+dir[0]*t,origin[1]+dir[1]*t]}}return out}
 function offset(x,y,site,dir,amount){let d=((x-site[0])**2+(y-site[1])**2)/210,k=amount*Math.exp(-d);return [dir[0]*k,dir[1]*k]}
 function draw(ctx,site,dir,s,scale=1,palette={color:"#dcb880",edge:"#90704d",light:"#f8dfac"},partner=null){let angle=Math.atan2(dir[1],dir[0]),radius=28,gap=partner?Math.max(12,(partner[0]-site[0])*dir[0]+(partner[1]-site[1])*dir[1]-radius):66;ctx.save();ctx.translate(...site);ctx.rotate(angle);
 // Partner cell remains still. Its own bud grows toward this membrane.
 ctx.beginPath();ctx.ellipse(gap+radius,0,radius,radius*.88,0,0,Math.PI*2);ctx.fillStyle='#89bfa8';ctx.fill();ctx.lineWidth=Math.max(1.5,.5/scale);ctx.strokeStyle='#467a6d';ctx.stroke();
 ctx.beginPath();ctx.moveTo(gap+4,-12);ctx.bezierCurveTo(gap-s.bulge,-10,gap-s.bulge,10,gap+4,12);ctx.fillStyle='#89bfa8';ctx.fill();ctx.stroke();
 // Two stems and two hands, each with three distinct curling fingers.
 function hand(base,direction,color,edge){let length=s.reach*Math.max(1,(gap-s.bulge*1.2)/2-2);if(length<.05)return;ctx.save();ctx.translate(base,0);ctx.scale(direction,1);ctx.strokeStyle=color;ctx.fillStyle=color;ctx.lineWidth=Math.max(4.4,1.05/scale);ctx.lineCap='round';ctx.lineJoin='round';ctx.beginPath();ctx.moveTo(0,0);ctx.bezierCurveTo(length*.3,2.8*(1-s.grip),length*.7,-2.0*(1-s.grip),length,0);ctx.stroke();for(let i=-1;i<=1;i++){ctx.beginPath();ctx.moveTo(length-1,0);ctx.bezierCurveTo(length+3,i*4.5,length+7,i*5*(1-s.grip*.7),length+7-s.grip*6,i*2.7);ctx.stroke()}ctx.restore()}
 hand(s.bulge*.6,1,palette.color,palette.edge);hand(gap-s.bulge*.6,-1,'#89bfa8','#467a6d');if(s.transfer!==undefined){let xx=gap*s.transfer;ctx.beginPath();ctx.ellipse(xx,0,6,5,0,0,Math.PI*2);ctx.fillStyle=s.transfer<.5?palette.color:'#89bfa8';ctx.fill();ctx.strokeStyle=s.transfer<.5?palette.edge:'#467a6d';ctx.lineWidth=1;ctx.stroke();ctx.beginPath();ctx.arc(xx,0,2.5,0,Math.PI*2);ctx.fillStyle='#d9f0bf';ctx.fill()}
 ctx.restore();}
 return {state,anchor,offset,draw};
})();
if(typeof module!=='undefined')module.exports=BondGesture;
