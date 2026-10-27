extends RefCounted
# Browser JIT kernel for the unchanged three-pass contact solver.
# Float32 vector operations match Godot Vector2; scalar physics stays Float64.
const SOURCE = """
globalThis.microcosmContacts = (() => {
 const f=Math.fround, add=(a,b)=>[f(a[0]+b[0]),f(a[1]+b[1])], sub=(a,b)=>[f(a[0]-b[0]),f(a[1]-b[1])];
 const mul=(a,k)=>{k=f(k);return [f(a[0]*k),f(a[1]*k)]}, div=(a,k)=>{k=f(k);return [f(a[0]/k),f(a[1]/k)]};
 const dot=(a,b)=>f(f(a[0]*b[0])+f(a[1]*b[1])), cross=(a,b)=>f(f(a[0]*b[1])-f(a[1]*b[0]));
 const len=a=>f(Math.sqrt(dot(a,a))), neg=a=>[-a[0],-a[1]];
 const rotate=(p,c,s)=>[f(f(p[0]*c)-f(p[1]*s)),f(f(p[0]*s)+f(p[1]*c))];
 // Float trigonometry follows Emscripten/musl, rather than rounding JS sin/cos.
 // Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
 // Developed at SunPro, a Sun Microsystems, Inc. business.
 // Permission to use, copy, modify, and distribute this software is freely
 // granted, provided that this notice is preserved.
 // Adapted from emscripten/system/lib/libc/musl/src/math/{sinf,cosf,__sindf,__cosdf}.c.
 const sbuf=new Float32Array(1),ibuf=new Uint32Array(sbuf.buffer);
 const sind=x=>{const z=x*x,w=z*z,r=-0.000198393348360966317347+z*0.0000027183114939898219064,s=z*x;return f((x+s*(-0.166666666416265235595+z*0.0083333293858894631756))+s*w*r)};
 const cosd=x=>{const z=x*x,w=z*z,r=-0.00138867637746099294692+z*0.0000243904487962774090654;return f(((1+z*-0.499999997251031003120)+w*0.0416666233237390631894)+(w*z)*r)};
 const sinf=x=>{x=f(x);sbuf[0]=x;const ix=ibuf[0]&0x7fffffff,sign=x<0;
  if(ix<=0x3f490fda)return ix<0x39800000?x:sind(x);
  if(ix<=0x407b53d1){if(ix<=0x4016cbe3)return sign?-cosd(x+Math.PI/2):cosd(x-Math.PI/2);return sind(sign?-(x+Math.PI):-(x-Math.PI))}
  if(ix<=0x40e231d5){if(ix<=0x40afeddf)return sign?cosd(x+3*Math.PI/2):-cosd(x-3*Math.PI/2);return sind(sign?x+2*Math.PI:x-2*Math.PI)}
  return f(Math.sin(x));};
 const cosf=x=>{x=f(x);sbuf[0]=x;const ix=ibuf[0]&0x7fffffff,sign=x<0;
  if(ix<=0x3f490fda)return ix<0x39800000?1:cosd(x);
  if(ix<=0x407b53d1){if(ix>0x4016cbe3)return -cosd(sign?x+Math.PI:x-Math.PI);return sind(sign?x+Math.PI/2:Math.PI/2-x)}
  if(ix<=0x40e231d5){if(ix>0x40afeddf)return cosd(sign?x+2*Math.PI:x-2*Math.PI);return sind(sign?-x-3*Math.PI/2:x-3*Math.PI/2)}
  return f(Math.cos(x));};
 function shape(r){return {p:r.slice(0,2),v:r.slice(2,4),w:r[4],r:r[5],box:r[6],cell:r[7],virus:r[8],im:r[9],ii:r[10],bounce:r[11],id:r[12],c:r[13],s:r[14],eligible:r[15],axes:[[r[13],r[14]],[-r[14],r[13]]]}}
 const extent=(a,n)=>a.box?Math.abs(dot(n,a.axes[0]))*43+Math.abs(dot(n,a.axes[1]))*13:a.r;
 const support=(a,n)=>a.box?add(add(a.p,mul(mul(a.axes[0],43),Math.sign(dot(n,a.axes[0])))),mul(mul(a.axes[1],13),Math.sign(dot(n,a.axes[1])))):add(a.p,mul(n,a.r));
 function hit(a,b){
  const dx=f(b.p[0]-a.p[0]),dy=f(b.p[1]-a.p[1]),reach=(a.box?45:a.r)+(b.box?45:b.r)+.02;
  if(f(f(dx*dx)+f(dy*dy))>reach*reach)return null;
  const d=[dx,dy];
  let n=[1,0],depth=0,p;
  if(!a.box&&!b.box){const distance=len(d);depth=a.r+b.r-distance;if(depth<-.02)return null;n=distance>.0001?div(d,distance):[1,0];p=add(a.p,mul(n,a.r-depth*.5));}
  else if(a.box&&b.box){depth=Infinity;for(const axis of [...a.axes,...b.axes]){const overlap=extent(a,axis)+extent(b,axis)-Math.abs(dot(d,axis));if(overlap<-.02)return null;if(overlap<depth){depth=overlap;n=dot(d,axis)>=0?axis:neg(axis)}}p=mul(add(support(a,n),support(b,neg(n))),.5);}
  else {const box=a.box?a:b,ball=a.box?b:a,local=rotate(sub(ball.p,box.p),box.c,-box.s);let closest=[Math.max(-43,Math.min(43,local[0])),Math.max(-13,Math.min(13,local[1]))];const difference=sub(local,closest),distance=len(difference);
   if(distance>.0001){depth=ball.r-distance;if(depth<-.02)return null;n=div(difference,distance)}
   else {const dx=43-Math.abs(local[0]),dy=13-Math.abs(local[1]);n=dx<dy?[local[0]>=0?1:-1,0]:[0,local[1]>=0?1:-1];closest=add(local,mul(n,Math.min(dx,dy)));depth=ball.r+Math.min(dx,dy)}
   n=rotate(n,box.c,box.s);if(!a.box)n=neg(n);p=add(box.p,rotate(closest,box.c,box.s));
  }return {n,depth:Math.max(0,depth),p};
 }
 function resolve(a,b,h,scale){
  const nx=h.n[0],ny=h.n[1],ax=f(h.p[0]-a.p[0]),ay=f(h.p[1]-a.p[1]),bx=f(h.p[0]-b.p[0]),by=f(h.p[1]-b.p[1]);
  const avx=f(a.v[0]+f(-ay*f(a.w))),avy=f(a.v[1]+f(ax*f(a.w))),bvx=f(b.v[0]+f(-by*f(b.w))),bvy=f(b.v[1]+f(bx*f(b.w)));
  const relative=f(f(f(bvx-avx)*nx)+f(f(bvy-avy)*ny));
  if(relative>=0&&h.depth<=.02)return;
  const aim=f(a.im),bim=f(b.im);
  if(relative<0){
   const ca=f(f(ax*ny)-f(ay*nx)),cb=f(f(bx*ny)-f(by*nx));
   const denom=a.im+b.im+(ca*ca)*a.ii+(cb*cb)*b.ii,bounce=relative < -2?Math.min(a.bounce,b.bounce):0,k=f(-(1+bounce)*relative/denom);
   let vx=f(nx*k),vy=f(ny*k);if((a.virus&&b.cell)||(b.virus&&a.cell)){vx=f(vx*f(scale));vy=f(vy*f(scale))}
   a.v=[f(a.v[0]-f(vx*aim)),f(a.v[1]-f(vy*aim))];a.w-=f(f(ax*vy)-f(ay*vx))*a.ii;
   b.v=[f(b.v[0]+f(vx*bim)),f(b.v[1]+f(vy*bim))];b.w+=f(f(bx*vy)-f(by*vx))*b.ii;
  }
  const depth=f(Math.max(0,h.depth-.02)),denom=f(a.im+b.im),cx=f(f(f(nx*depth)*f(.65))/denom),cy=f(f(f(ny*depth)*f(.65))/denom);
  a.p=[f(a.p[0]-f(cx*aim)),f(a.p[1]-f(cy*aim))];b.p=[f(b.p[0]+f(cx*bim)),f(b.p[1]+f(cy*bim))];
 }
 function contacts(bodies,scale,groups={}){
  const grid=new Map(),cells=new Map(),tiles=[],pairs=[],found=new Map();
  bodies.forEach((b,i)=>{const tile=[Math.floor(b.p[0]/96),Math.floor(b.p[1]/96)];tiles.push(tile);if(!b.eligible)return;const key=tile.join(',');if(!grid.has(key))grid.set(key,[]);grid.get(key).push(i);if(b.cell){if(!cells.has(key))cells.set(key,[]);cells.get(key).push(i)}});
  bodies.forEach((b,i)=>{if(!b.eligible)return;const map=b.cell?grid:cells,t=tiles[i];for(let y=-1;y<=1;y++)for(let x=-1;x<=1;x++)for(const j of map.get((t[0]+x)+','+(t[1]+y))||[])if(j>i&&!(groups[b.id]!==undefined&&groups[b.id]===groups[bodies[j].id]))pairs.push([i,j])});
  for(let pass=0;pass<3;pass++)for(const [i,j] of pairs){const a=bodies[i],b=bodies[j],h=hit(a,b);if(!h)continue;const ids=[Math.min(a.id,b.id),Math.max(a.id,b.id)];found.set(ids.join(','),ids);resolve(a,b,h,scale)}
  return found;
 }
 function run(rows,scale){const bodies=rows.map(shape),found=contacts(bodies,scale);return [bodies.map(b=>[...b.p,...b.v,b.w]),[...found.values()]];}
 const limit=(v,max)=>{max=f(max);const l=len(v);return l>0&&max<l?mul(div(v,l),max):v};
 function advance(rows,delta,steps,scale,links=[],stiffness=0,damping=0,groups={}){
  const bodies=rows.map(shape),found=new Map(),dt=delta/steps;

  bodies.forEach((b,i)=>b.angle=rows[i][16]);
  for(let step=0;step<steps;step++){
   for(const [ai,bi,rest] of links){const a=bodies[ai],b=bodies[bi],offset=sub(b.p,a.p),length=len(offset);if(length<.001)continue;
    const normal=div(offset,length),relative=dot(sub(b.v,a.v),normal);
    const axisA=[cosf(a.angle),sinf(a.angle)],axisB=[cosf(b.angle),sinf(b.angle)];
    const armA=mul(axisA,Math.min(25,extent(a,normal))),armB=mul(axisB,Math.min(25,extent(b,neg(normal))));
    const inverse=a.im+b.im+(cross(armA,normal)*cross(armA,normal))/rows[ai][28]+(cross(armB,normal)*cross(armB,normal))/rows[bi][28];
    const force=div(mul(normal,(length-rest)*stiffness+relative*damping),1+(damping*dt+stiffness*dt*dt)*inverse);
    const valueA=mul(force,dt),valueB=mul(neg(force),dt),pointA=add(a.p,armA),pointB=sub(b.p,armB);
    a.v=add(a.v,div(valueA,rows[ai][23]));a.w+=cross(sub(pointA,a.p),valueA)/rows[ai][28];
    b.v=add(b.v,div(valueB,rows[bi][23]));b.w+=cross(sub(pointB,b.p),valueB)/rows[bi][28];
   }
   bodies.forEach((b,i)=>{const r=rows[i];b.angle=r[16];if((!b.cell&&!b.virus)||r[19])return;
    if(b.virus&&r[20]){b.v=[0,0];b.w=0}
    const target=[r[17],r[18]];
    if(dot(target,target)>0){const force=limit(mul(sub(target,b.v),r[21]),r[22]);b.v=add(b.v,mul(div(force,r[23]),dt))}
    b.v=limit(mul(b.v,r[29]),r[26]);b.w=Math.max(-r[27],Math.min(r[27],b.w*r[30]));
    b.p=add(b.p,mul(b.v,dt));
    if(b.cell){const range=Math.PI*2,value=b.angle+b.w*dt;b.angle=value-range*Math.floor((value+Math.PI)/range);if(Math.abs(b.angle-Math.PI)<Math.max(1e-5,1e-5*Math.abs(b.angle)))b.angle=-Math.PI;r[16]=b.angle;
     b.c=cosf(b.angle);b.s=sinf(b.angle);b.axes=[[b.c,b.s],[-b.s,b.c]];
     const ex=extent(b,[1,0]),ey=extent(b,[0,1]),x=Math.max(f(-620+ex),Math.min(f(620-ex),b.p[0])),y=Math.max(f(-365+ey),Math.min(f(350-ey),b.p[1]));
     if(x!==b.p[0])b.v[0]=f(-b.v[0]*b.bounce);if(y!==b.p[1])b.v[1]=f(-b.v[1]*b.bounce);b.p=[x,y];
    }
   });
   for(const [k,v] of contacts(bodies,scale,groups))found.set(k,v);
  }

  return new Float64Array([...bodies.flatMap(b=>[...b.p,...b.v,b.w,b.angle]),...[...found.values()].flat()]);
 }
 const unpack=(text,stride)=>{const raw=atob(text),bytes=new Uint8Array(raw.length);for(let i=0;i<raw.length;i++)bytes[i]=raw.charCodeAt(i);const data=new Float64Array(bytes.buffer),rows=[];for(let i=0;i<data.length;i+=stride)rows.push(Array.from(data.subarray(i,i+stride)));return rows};
 // Geometry2D segment predicate, with the same Float32 operation order and epsilon.
 // Derived from Godot Engine core/math/geometry_2d.h (MIT; see assets/licenses/godot-math.txt).
 const eps=f(0.00001);
 function intersects(a,b,c,d){
  const B=sub(b,a),C0=sub(c,a),D0=sub(d,a),length=dot(B,B);if(length<=0)return false;
  const n=div(B,length),C=[dot(C0,n),f(f(C0[1]*n[0])-f(C0[0]*n[1]))],D=[dot(D0,n),f(f(D0[1]*n[0])-f(D0[0]*n[1]))];
  if((C[1]<-eps&&D[1]<-eps)||(C[1]>eps&&D[1]>eps))return false;
  if(C[1]===D[1]||Math.abs(f(C[1]-D[1]))<Math.max(eps,f(eps*Math.abs(C[1]))))return false;
  const pos=f(D[0]+f(f(f(C[0]-D[0])*D[1])/f(D[1]-C[1])));
  return pos>=0&&pos<=1;
 }
 const corners=[[-43,-13],[43,-13],[43,13],[-43,13]];
 function visible(origin,target,walls){
  const lower=[f(Math.min(origin[0],target[0])-45),f(Math.min(origin[1],target[1])-45)],upper=[f(Math.max(origin[0],target[0])+45),f(Math.max(origin[1],target[1])+45)];
  for(const w of walls){if(w[0]<lower[0]||w[0]>upper[0]||w[1]<lower[1]||w[1]>upper[1])continue;
   const a=rotate(sub(origin,w),w[2],w[3]),b=rotate(sub(target,w),w[2],w[3]);
   if(Math.max(a[0],b[0])<-43||Math.min(a[0],b[0])>43||Math.max(a[1],b[1])<-13||Math.min(a[1],b[1])>13)continue;
   if(a[0]>=-43&&a[0]<43&&a[1]>=-13&&a[1]<13)continue;
   for(let i=0;i<4;i++)if(intersects(a,b,corners[i],corners[(i+1)%4]))return false;
  }return true;
 }
 function nearestVisible(input){
  const [origins,targets,walls,radius]=JSON.parse(input);
  return JSON.stringify(origins.map(origin=>{let best=-1,distance=radius;
   for(let i=0;i<targets.length;i++){const v=targets[i];if(!v[2])continue;const d=len(sub(v,origin));if(d<distance&&visible(origin,v,walls)){best=i;distance=d}}
   return best;}));
 }
 function coreStep(input){
  const [rows,links,count,dt,drift,stiffness,decay]=JSON.parse(input),positions=rows.map(r=>r.slice(0,2)),velocities=rows.map(r=>r.slice(3,5));
  for(let step=0;step<count;step++){
   let center=[0,0],living=0;
   for(let i=0;i<rows.length;i++)if(rows[i][2]){center=add(center,positions[i]);living++}
   if(living){center=div(center,living);const offset=mul(center,drift);for(let i=0;i<rows.length;i++)if(rows[i][2])positions[i]=add(positions[i],offset)}
   const forces=rows.map(()=>[0,0]);
   for(const [a,b] of links){if(!rows[a][2]||!rows[b][2])continue;const offset=sub(positions[b],positions[a]),distance=len(offset);if(distance<.001)continue;
    const force=mul(mul(div(offset,distance),distance-26),stiffness);forces[a]=add(forces[a],force);forces[b]=sub(forces[b],force);}
   for(let i=0;i<rows.length;i++)if(rows[i][2]){
    velocities[i]=limit(mul(add(velocities[i],mul(forces[i],dt)),decay),650);
    const next=add(positions[i],mul(velocities[i],dt));positions[i]=[Math.max(-550,Math.min(550,next[0])),Math.max(-300,Math.min(280,next[1]))];
   }
   for(let pass=0;pass<8;pass++)for(let i=0;i<rows.length;i++)if(rows[i][2])for(let j=i+1;j<rows.length;j++)if(rows[j][2]){
    const dx=f(positions[j][0]-positions[i][0]),dy=f(positions[j][1]-positions[i][1]),squared=f(f(dx*dx)+f(dy*dy));if(squared>=676)continue;const distance=f(Math.sqrt(squared));if(distance>=26)continue;const offset=[dx,dy];
    const normal=distance>.001?div(offset,distance):rows[i].slice(5,7),correction=div(mul(normal,26-distance),2);
    positions[i]=sub(positions[i],correction);positions[j]=add(positions[j],correction);
   }
  }
  return new Float32Array(positions.flatMap((p,i)=>[...p,...velocities[i]]));
 }
 // Compile the hot JIT paths while the scene loads, using disposable bodies.
 // These arrays never enter the game and do not advance its clock or RNG.
 function warm(){
  const rows=[];
  for(let i=0;i<96;i++){
   const cell=i<16,virus=i>=16&&i<76,angle=(i%7)*.3;
   rows.push([(i%12)*20-110,Math.floor(i/12)*20-70,2,-3,.1,cell?18:virus?10:13,cell?1:0,cell?1:0,virus?1:0,1,.01,.2,i,cosf(angle),sinf(angle),1,angle,0,virus?-30:0,0,0,8,300,1,1,1,250,8,100,.99,.99]);
  }
  const cores=Array.from({length:20},(_,i)=>[(i%5)*24,Math.floor(i/5)*24,true,0,0,1,0]);
  const coreInput=JSON.stringify([cores,[],2,1/120,-.0001,30,.99]);
  for(let i=0;i<120;i++){advance(rows.map(r=>r.slice()),1/60,2,1,[],30,2);coreStep(coreInput)}
 }
 warm();
 let materials=[];
 function advanceCompact(text,config,links){
  const p=JSON.parse(config),rows=unpack(text,13).map(d=>{const r=materials[d[12]].slice();r[0]=d[0];r[1]=d[1];r[2]=d[2];r[3]=d[3];r[4]=d[4];r[12]=d[5];r[16]=d[6];r[17]=d[7];r[18]=d[8];r[15]=d[9];r[19]=d[10];r[20]=d[11];if(r[6]){r[13]=cosf(r[16]);r[14]=sinf(r[16])}return r});
  return advance(rows,p[0],p[1],p[2],JSON.parse(links),p[3],p[4],p[5]);
 }
 return {advanceCompact,setMaterials:text=>materials=JSON.parse(text),advance,nearestVisible,visible,coreStep,advanceBinary:(text,config,links)=>{const p=JSON.parse(config);return advance(unpack(text,31),p[0],p[1],p[2],JSON.parse(links),p[3],p[4],p[5])}};
})();
"""
