/* Geometry and organ responses for catalog rigs; no gameplay state is written. */
const LivingFeatures=(()=>{
 const Catalog=typeof LivingCatalog!=='undefined'?LivingCatalog:require('./living-catalog.js'),Bond=typeof BondGesture!=='undefined'?BondGesture:require('./bond-gesture.js');
 const TAU=Math.PI*2,clamp=x=>Math.max(0,Math.min(1,x)),ease=x=>{x=clamp(x);return x*x*(3-2*x)},mix=(a,b,t)=>a+(b-a)*t;
 const reserved=new WeakMap();
 function reservations(sp,poly){
  if(reserved.has(sp))return reserved.get(sp);
  if(!['chambers','seeds','gold','reservoir','beads','contacts','cassette'].includes(sp.feature))return [];
  let n=sp.count||(sp.shape==='wall'?5:sp.feature==='cassette'?3:['gold','reservoir'].includes(sp.feature)?1:2),radius=['gold','reservoir'].includes(sp.feature)?14:sp.shape==='wall'?4.5:6;
  let wanted=Array.from({length:n},(_,i)=>sp.shape==='wall'?{x:-62+i*16,y:0,r:radius}:{x:-48+(i%4)*19,y:27+Math.floor(i/4)*19,r:radius});
  if(!poly)return wanted;
  const margin=(x,y)=>{let inside=false,d=Infinity;for(let i=0,j=poly.length-1;i<poly.length;j=i++){let a=poly[i],b=poly[j];if((a[1]>y)!==(b[1]>y)&&x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])inside=!inside;let dx=b[0]-a[0],dy=b[1]-a[1],t=clamp(((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy||1));d=Math.min(d,Math.hypot(x-a[0]-t*dx,y-a[1]-t*dy))}return inside?d:-d;};
  let result=[],f=sp.face;
  for(let ideal of wanted){let best=null,score=Infinity;for(let y=-72;y<=72;y+=3)for(let x=-90;x<=90;x+=3){if(margin(x,y)<radius*1.15+5||Math.hypot((x-f[0])/(f[2]*.52+radius+4),(y-f[1])/(f[2]*.43+radius+4))<=1||result.some(r=>Math.hypot(x-r.x,y-r.y)<radius+r.r+5))continue;let d=(x-ideal.x)**2+(y-ideal.y)**2;if(d<score){score=d;best={x,y,r:radius}}}if(!best)throw Error('No room for functional chamber: '+sp.id);result.push(best);}
  reserved.set(sp,result);return result;
 }
 function nearestSurface(poly,p){let best=null,d=Infinity;for(let i=0;i<poly.length;i++){let a=poly[i],b=poly[(i+1)%poly.length],dx=b[0]-a[0],dy=b[1]-a[1],u=clamp(((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy||1)),q=[a[0]+dx*u,a[1]+dy*u],dist=Math.hypot(q[0]-p[0],q[1]-p[1]);if(dist<d){d=dist;best=q}}return best;}

 function line(c,pts,color,width){c.strokeStyle=color;c.lineWidth=width;c.lineCap='round';c.lineJoin='round';c.beginPath();pts.forEach((p,i)=>i?c.lineTo(...p):c.moveTo(...p));c.stroke()}
 function dot(c,x,y,r,color,edge){c.beginPath();c.arc(x,y,Math.max(.01,r),0,TAU);c.fillStyle=color;c.fill();if(edge){c.strokeStyle=edge;c.lineWidth=1.3;c.stroke()}}
 function outline(c,a,api,factor,color,width){let pts=a.poly.filter((_,i)=>i%3===0).map(p=>api.deform(a,p[0]*factor,p[1]*factor));c.strokeStyle=color;c.lineWidth=width;c.beginPath();pts.forEach((p,i)=>i?c.lineTo(...p):c.moveTo(...p));c.closePath();c.stroke()}
 function appendages(c,a,lod,scale,api){let sp=a.spec,s=Catalog.state(a);if(!sp.motor)return;let count=sp.motor==='orbit'?12:sp.motor==='wave'?8:7;
 for(let j=0;j<count;j++){let angle=sp.motor==='rear'?Math.PI+(j-(count-1)/2)*.105:sp.motor==='orbit'?j/count*TAU:Math.PI+(j%2?1:-1)*.7;
 let base=Bond.anchor(a.poly,sp.shape==='crescent'?[-40,0]:[0,0],[Math.cos(angle),Math.sin(angle)]);if(sp.motor==='wave'){base=nearestSurface(a.poly,[-60+j*17,j%2?-65:65]);angle=j%2?-Math.PI/2:Math.PI/2};let root=api.deform(a,...base),length=sp.motor==='orbit'?42:27+(j%3)*3,segments=lod?7:18,pts=[];
 for(let i=0;i<=segments;i++){let u=i/segments,phase=a.phase*8-u*6+j*.6,bend=Math.sin(phase)*(1+s.motor*6)*u*u;pts.push([root[0]+Math.cos(angle)*length*u-Math.sin(angle)*bend,root[1]+Math.sin(angle)*length*u+Math.cos(angle)*bend])}line(c,pts,sp.edge,Math.max(2.5,.5/scale));line(c,pts,sp.light,Math.max(1.25,.27/scale))}
 }
 function hands(c,a,lod,scale,api){let sp=a.spec,s=Catalog.state(a),connector=['bond','bodyguard','radar','swapper','accelerator','kinetic_bond'].includes(sp.id),core=sp.id==='core';if(!connector&&!core)return;
 let number=core?6:2;for(let i=0;i<number;i++){let angle=core?i/6*TAU:i*Math.PI,dir=[Math.cos(angle),Math.sin(angle)],site=Bond.anchor(a.poly,[0,0],dir),root=api.deform(a,...site);
 if(['bridge','coreBond'].includes(a.mode)&&(core?i===0:true)){let gesture=Bond.state(a.time);Bond.draw(c,[root[0]-dir[0]*gesture.bulge,root[1]-dir[1]*gesture.bulge],dir,gesture,scale,sp);continue}
 if(a.bond&&dir[0]*a.bond.dir[0]+dir[1]*a.bond.dir[1]>.85)continue;let length=core?12:26;if(a.mode==='tension')length+=8*Math.sin(a.time*1.4+i);let tip=[root[0]+dir[0]*length,root[1]+dir[1]*length];line(c,[root,[root[0]+dir[0]*length*.5-dir[1]*Math.sin(a.time)*3,root[1]+dir[1]*length*.5+dir[0]*Math.sin(a.time)*3],tip],sp.edge,Math.max(4,.7/scale));line(c,[root,tip],sp.color,Math.max(2.6,.45/scale));for(let f=-1;f<=1;f++)line(c,[tip,[tip[0]+dir[0]*5-dir[1]*f*3,tip[1]+dir[1]*5+dir[0]*f*3]],sp.color,Math.max(2.5,.45/scale));}
 }
 function internals(c,a,lod,scale,api){let sp=a.spec,s=Catalog.state(a),feature=sp.feature,accent=sp.accent||sp.light;const pos=(x,y)=>api.deform(a,x,y);
 if(['rims','skirt','core','collar','embrace'].includes(feature)){let n=feature==='rims'?3:feature==='skirt'?2:1;for(let j=0;j<n;j++){let factor=.90-j*.16;if(a.mode==='growRing')factor=.45+s.ring*.45;if(a.mode==='immune')factor+=s.trigger*.03;outline(c,a,api,factor,feature==='core'?sp.edge:accent,feature==='core'?3:2)}}
 if(feature==='seams'){for(let j=0;j<8;j++){let t=j/8*TAU,p=pos(Math.cos(t)*54,Math.sin(t)*54),q=pos(Math.cos(t)*67,Math.sin(t)*67);line(c,[p,q],sp.edge,1.5)}}
 for(let [i,r] of reservations(sp).entries()){let p=pos(r.x,r.y),count=sp.count||reservations(sp).length,fill=clamp(s.load*count-i),pulse=(['generate','economy','reward','charge','conduct'].includes(a.mode)?Math.max(0,Math.sin(a.time*7-i*.8)):0);dot(c,...p,r.r*(1+pulse*.13),sp.edge);dot(c,...p,r.r*.79,sp.light);if(fill>0)dot(c,...p,r.r*.72*Math.sqrt(fill),sp.id==='seeker_factory'?(i===0?'#b99acb':'#f5d273'):accent);}
 if(['radar','folds','accordion','cassette','guard'].includes(feature)){let count=feature==='radar'?4:3;for(let j=0;j<count;j++){let pts=[];for(let i=0;i<=24;i++){let u=i/24,x=-55+u*82,y=-35+j*10+Math.sin(u*Math.PI)*(-12-(a.mode==='radar'?Math.sin(a.time)*4:0));if(feature==='cassette')y=28+j*7+Math.sin(u*TAU)*3+(1-s.load)*3;if(feature==='accordion')x=-52+j*9,y=-36+u*72+Math.sin(u*TAU*2)*4;pts.push(pos(x,y))}line(c,pts,accent,2)}}
 if(['exchange','channel','spiral'].includes(feature)){let pts=[];for(let i=0;i<=40;i++){let u=i/40,x,y;if(feature==='spiral'){let t=u*TAU*1.6;x=-28+Math.cos(t)*u*25;y=15+Math.sin(t)*u*25}else{x=-55+u*97;y=27+Math.sin(u*TAU)*10}pts.push(pos(x,y))}line(c,pts,accent,2);if(feature==='exchange'){let q=a.mode==='swap'?ease(s.t/2):a.mode==='noPartner'?Math.sin(clamp(s.t/2)*Math.PI)*.3:0;for(let j=0;j<2;j++){let u=j?1-q:q,p=pos(-45+u*80,27+Math.sin(u*TAU)*10);dot(c,...p,8,j?'#f1cc7d':'#9cdacb',sp.edge)}}else{let u=(a.time*(a.mode==='kinetic'?.5:.14))%1,p=pts[Math.min(40,Math.floor(u*40))];dot(c,...p,4,accent)}}
 if(feature==='poles'){for(let side of [-1,1]){let p=pos(52,side*47);dot(c,...p,10,sp.light,sp.edge);dot(c,...p,8*Math.sqrt(s.load),accent);if(a.mode==='charge')dot(c,...p,2+s.load*2,'#fff0b0')}}
 if(feature==='sensors'){for(let side of [-1,1]){let p=pos(56,side*(36+s.trigger*4));dot(c,...p,7,accent,sp.edge)}}
 if(feature==='pores'){for(let j=0;j<7;j++){let angle=-Math.PI/2+j/6*Math.PI,p=pos(Math.cos(angle)*64,Math.sin(angle)*58),open=a.mode==='spray'?Math.max(0,Math.sin(s.t*8-j)):a.mode==='empty'?1-ease(s.t):.3;dot(c,...p,2+open*2,sp.edge);}}
 if(feature==='patches'){for(let j=0;j<3;j++){let p=pos(-42+j*25,30);dot(c,...p,10*(a.mode==='morph'?1-ease(s.t/2):1),['#d6cb99','#b6dbcf','#b8c4d9'][j])}}
 }
 function ports(c,a,lod,scale,api){let sp=a.spec,s=Catalog.state(a);if(!sp.ports&&!sp.intake)return;let type=sp.ports,dirs=type==='double'?[-1,1]:[1],count=type==='triple'?3:type==='factory'?2:1;
 for(let dir of dirs)for(let j=0;j<count;j++){let yy=(j-(count-1)/2)*23,base=Bond.anchor(a.poly,[0,0],[dir,yy/90]),p=api.deform(a,...base),width=type==='wide'||type==='hungry'?15:type==='long'?7:10,len=type==='long'?37:type==='factory'?21:18;
 let pulse=a.mode==='reload'?1-ease(s.t/1.2):s.fire;let localPhase=(a.time*(a.mode==='accelerate'?2+ease(s.t/4)*4:2)-j/3+99)%1;if(type==='triple')pulse=Math.max(0,Math.sin(localPhase*TAU))*(s.shot?1:.05);let open=width*(1+(a.mode==='caliber'?.35*ease(s.t/2):pulse*.45)+(s.feed?s.trigger*.4:0));
 let weights=api.faceWeights(a);open+=(weights.astonished||0)*5+(weights.surprised||0)*3-(weights.kiss||0)*4+(weights.laugh||0)*Math.abs(Math.sin(a.time*7))*2;
 c.save();c.translate(...p);c.scale(dir,1);c.beginPath();c.moveTo(-12,-width);c.bezierCurveTo(0,-width*.6,len,-width*.7,len,-open);c.lineTo(len,open);c.bezierCurveTo(len*.4,width*.7,0,width*.6,-12,width);c.closePath();c.fillStyle=sp.color;c.fill();c.strokeStyle=sp.edge;c.lineWidth=Math.max(2,.5/scale);c.stroke();c.beginPath();c.ellipse(len,0,Math.max(3,open*.38),open,0,0,TAU);c.fillStyle=sp.edge;c.fill();c.strokeStyle=sp.light;c.stroke();c.restore();
 let flight=type==='triple'?(localPhase>.25?(localPhase-.25)/.75:-1):s.bullet;if(flight>=0&&s.shot&&(type!=='factory'||j===0)){let distance=len+10+flight*70;if(a.mode==='spawn'){let x=p[0]+dir*distance,y=p[1];c.save();c.translate(x,y);c.scale(.24,.24);c.fillStyle='#9ec9aa';c.beginPath();c.moveTo(-38,-22);c.bezierCurveTo(-18,-40,10,-22,28,-36);c.bezierCurveTo(51,-41,50,-10,32,-7);c.bezierCurveTo(56,6,36,33,20,20);c.bezierCurveTo(-7,40,-42,29,-38,-22);c.fill();for(let i=-1;i<=1;i++)line(c,[[-35,i*9],[-50,i*12-4],[-60,i*12]],'#567d66',3);dot(c,10,-6,4,'#573b31');dot(c,20,-6,4,'#573b31');c.restore()}else if(a.mode==='launchBomb'){let x=p[0]+dir*distance,y=p[1];dot(c,x,y,10,'#d5ab6b','#81603f');for(let k=0;k<6;k++){let angle=k/6*TAU;line(c,[[x+Math.cos(angle)*6,y+Math.sin(angle)*6],[x+Math.cos(angle)*9,y+Math.sin(angle)*9]],'#81603f',.8)}dot(c,x+2,y-2,1,'#513729');dot(c,x+5,y-2,1,'#513729')}else dot(c,p[0]+dir*distance,p[1],a.mode==='heavyShot'?7:3.5,accentFor(a),sp.edge);}
 }
 }
 const accentFor=a=>a.spec.accent||'#f5d273';
 function effects(c,a,lod,scale,api){let sp=a.spec,s=Catalog.state(a),mode=a.mode,accent=accentFor(a),green='#9ed6bd',yellow='#f5d273',t=s.t;
 const ring=(r,color,width=2)=>{c.strokeStyle=color;c.lineWidth=Math.max(width,.5/scale);c.beginPath();c.ellipse(0,0,r,r*.82,0,0,TAU);c.stroke()};
 const neighbour=(x,y,color=green)=>{dot(c,x,y,16,color);dot(c,x+4,y-2,2,'#573b31')};
 const flow=(from,to,progress,color,r=4)=>{let u=clamp(progress);dot(c,mix(from[0],to[0],u),mix(from[1],to[1],u),r,color)};
 if(s.feed){let n=sp.feedCount||sp.count|| (mode==='recipe'?3:mode==='loadFour'?4:mode==='loadThree'?3:2),u=s.p/1.8;for(let i=0;i<n;i++){let f=u*n-i;if(f>=0&&f<1)flow([136,24*(i%3-1)],[60,0],f,mode==='recipe'&&i===0?'#b99acb':yellow,4)} }
 if(['growRing','economy','generate','chargeHeal','heal','buff','healNetwork','boost','network','conduct','guard'].includes(mode)){
 if(mode==='growRing')outline(c,a,api,.45+s.ring*.48,accent,2);else if(mode==='economy')ring(35+s.ring*26,yellow);else if(['chargeHeal','generate'].includes(mode)){if(s.p<1.7)ring(18+s.ring*45,mode==='chargeHeal'?green:yellow)}else{
 let ends=mode==='heal'?[[120,-40],[120,40]]:[[122,0]];for(let end of ends){neighbour(...end);line(c,[[70,0],end],sp.edge,1);flow(mode==='guard'?end:[65,0],mode==='guard'?[65,0]:end,s.ring,['conduct','boost'].includes(mode)?yellow:green)}
 }
 }
 if(mode==='swap'||mode==='noPartner'){if(mode==='swap'){neighbour(122,0);line(c,[[72,0],[105,0]],sp.color,3);flow([70,-5],[106,-5],ease(t/2),yellow);flow([106,5],[70,5],ease(t/2),green)}}
 if(mode==='zap'){neighbour(125,0,'#b674a4');if(s.p>.4&&s.p<.72){let pts=[];for(let i=0;i<8;i++)pts.push([58+i*9,i===0||i===7?0:(i%2?6:-6)]);line(c,pts,yellow,Math.max(2,.7/scale))}}
 if(mode==='radar'){for(let j=0;j<3;j++){let r=75+((a.time*16+j*24)%72);c.strokeStyle=green;c.lineWidth=Math.max(1,.35/scale);c.beginPath();c.arc(0,0,r,-.6,.6);c.stroke()}}
 if(mode==='magnetic'||mode==='fieldContact'){let level=sp.id==='electromagnet'?ease(t/1.2)*(1-ease((t-4)/1.2)):1;if(level<.001)return;c.save();c.globalAlpha=level;for(let side of [-1,1]){let pts=[];for(let i=0;i<=20;i++){let u=i/20;pts.push([mix(45,135,u),side*(42+Math.sin(u*Math.PI)*22)])}line(c,pts,sp.edge,1);let u=1-(a.time*.4+(side+1)*.2)%1;dot(c,mix(45,135,u),side*(42+Math.sin(u*Math.PI)*22),3,accent)}if(mode==='fieldContact')dot(c,58,45,4+s.trigger*3,sp.light);c.restore()}
 if(['dropTag','trail','spray'].includes(mode)){let n=mode==='spray'?7:mode==='trail'?4:1;for(let i=0;i<n;i++){let age=s.p-i*(mode==='spray'?.1:.4);if(age<0||age>1.8)continue;let angle=mode==='spray'?-Math.PI/2+i/6*Math.PI:Math.PI,dist=75+clamp(age)*48;dot(c,Math.cos(angle)*dist,Math.sin(angle)*dist,3.5,'#d6bce6',sp.edge)}}
 if(['push','explode','deathPush','healDeath'].includes(mode)&&s.p>.3&&s.p<2){let color=mode==='healDeath'?green:accent,rad=65+ease((s.p-.3)/1.7)*85;ring(rad,color,mode==='explode'?4:2);for(let j=0;j<6;j++){let angle=j/6*TAU;dot(c,Math.cos(angle)*rad,Math.sin(angle)*rad*.82,mode==='healDeath'?5:3,color)}}
 if(mode==='immune'||(mode==='jump'&&s.jump>.05)||(mode==='land'&&s.t<.7)){c.save();c.globalAlpha=mode==='immune'?s.trigger:mode==='land'?1-ease(s.t/.7):1;outline(c,a,api,1.06,sp.light,2);if(mode==='jump')for(let i=0;i<3;i++)line(c,[[-95-i*12,-17+i*17],[-78-i*12,-17+i*17]],sp.light,2);c.restore()}
 if(mode==='sense'||mode==='retarget'||mode==='aimFixed'){let end=mode==='aimFixed'?[135,0]:[120,Math.sin(a.time)*35];neighbour(...end,'#a56f9e');if(mode==='sense'){c.strokeStyle=sp.light;c.lineWidth=1;c.beginPath();c.arc(0,0,108,-.45,.45);c.stroke()}}
 if(mode==='mergeReady'){neighbour(126,0,'#e3d4a4');flow([75,0],[109,0],ease(t/2),green,3)}
 if(mode==='reward'||mode==='sell'){let u=ease(s.t/2);dot(c,70+u*65,-u*65,6,yellow,sp.edge)}
 }
 return {reservations,appendages,hands,internals,ports,effects};
})();
if(typeof module!=='undefined')module.exports=LivingFeatures;
