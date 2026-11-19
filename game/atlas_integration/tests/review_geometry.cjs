const assert=require('node:assert/strict'),fs=require('fs'),vm=require('vm');
const L=require('../source/living-engine.js');
const rules=require('../source/organelle-rules.json').rules;
let checks=0;
for(const spec of L.specs){
 const a=L.create(spec,rules);
 for(const mode of ['idle','move','hurt','death',...(spec.id.includes('bomb')?['explode']:[])]){
  a.time=0;a.faceLayoutTime=-1;a.displayOrgTime=-1;
  for(let step=0;step<150;step++){
   L.update(a,1/60,mode,'auto',[.8,.6]);
   if(step%30)continue;
   const face=L.faceLayout(a),poly=a.poly.map(p=>L.deform(a,...p));
   assert(L.inside(face,poly),`${spec.id} ${mode}: face outside`);
   for(let i=0;i<16;i++){let t=i/16*Math.PI*2;assert(L.inside([face[0]+Math.cos(t)*face[2]*.47,face[1]+Math.sin(t)*face[2]*.59],poly),`${spec.id} ${mode}: face envelope outside`);}
   const organs=L.displayOrganelles(a).filter(Boolean);
   for(let i=0;i<organs.length;i++){
    const o=organs[i];assert(L.distance([o.x,o.y],poly)>o.r+1);
    assert(Math.hypot((o.x-face[0])/(face[2]*.52+o.r+3),(o.y-face[1])/(face[2]*.62+o.r+3))>1);
    for(let j=i+1;j<organs.length;j++)assert(Math.hypot(o.x-organs[j].x,o.y-organs[j].y)>o.r+organs[j].r+2.9);
   }
   checks++;
  }
  if(mode==='death'){assert(L.lifecycle(a).alpha===0);assert(a.faceWeights.hurt>.99);}
  if(mode==='explode'){assert(a.faceWeights.astonished>.99);assert(a.faceWeights.hurt<.001);}
 }
}
for(const name of ['raised_brow','astonished'])assert.equal(L.reactions[name].reduce((a,b)=>a+b),2);
let basic=L.create(L.specs.find(s=>s.id==='virus_basic'),[]);L.update(basic,.5,'move','calm',[1,0]);assert.deepEqual(L.deform(basic,20,0),[20,0]);
let wave=L.create(L.specs.find(s=>s.id==='virus_wave'),[]);wave.mode='wave';wave.time=1;assert(Math.abs(L.bodyRotation(wave)-Math.PI*2)<1e-8);wave.time=3;assert(Math.abs(L.bodyRotation(wave)+Math.PI*2)<1e-8);
const star=L.create(L.specs.find(s=>s.id==='wildcard'),[]);star.mode='morph';for(let t=0;t<3;t+=.1){star.time=t;for(const q of star.poly)assert(L.deform(star,...q).every(Number.isFinite),'Wildcard vertex ray produced nonfinite morph');}
for(const id of ['orbiter','virus_wave']){const a=L.create(L.specs.find(s=>s.id===id),[]);for(let j=0;j<120;j++){L.update(a,1/30,id==='orbiter'?'orbit':'wave','auto',[Math.cos(j/20),Math.sin(j/20)]);const f=L.faceLayout(a),r=-L.bodyRotation(a),poly=a.poly.map(q=>L.deform(a,...q));for(let i=0;i<32;i++){let x=Math.cos(i/32*L.TAU)*f[2]*.48,y=Math.sin(i/32*L.TAU)*f[2]*.60;assert(L.inside([f[0]+x*Math.cos(r)-y*Math.sin(r),f[1]+x*Math.sin(r)+y*Math.cos(r)],poly),'Upright face outside rotated body');}}}
console.log('PASS',checks,'rig/action phases: face and organelle boundaries, exclusion, separation; death exceptions; reaction timing; Basic disk; Wave rotations.');
