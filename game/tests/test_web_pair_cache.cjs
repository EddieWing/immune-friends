// Run with node game/tests/test_web_pair_cache.cjs. No browser or player save.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
function kernel(file,fallback=false){
 const context=vm.createContext({atob});
 if(fallback)vm.runInContext('Uint8Array.fromBase64=undefined',context);
 const native=vm.runInContext('typeof Uint8Array.fromBase64 === "function"',context);
 vm.runInContext(fs.readFileSync(path.join(__dirname,file),'utf8').split('"""')[1],context);
 return {api:context.microcosmContacts,native};
}
const previous=kernel('fixtures/legacy_pair_kernel.gd').api;
const candidates=[kernel('../scripts/web_physics.gd'),kernel('../scripts/web_physics.gd',true)];
let seed=731;
const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296};
let checks=0;
function compare(rows,groups={},steps=1,links=[]){
 const compact=rows.flatMap((r,i)=>[r[0],r[1],r[2],r[3],r[4],r[12],r[16],r[17],r[18],r[15],r[19],r[20],i]);
 const text=Buffer.from(new Float64Array(compact).buffer).toString('base64');
 const config=JSON.stringify([1/60,steps,.03,30,2,groups]);
 previous.setMaterials(JSON.stringify(rows));
 const expected=previous.advanceCompact(text,config,JSON.stringify(links));
 for(const {api} of candidates){
  api.setMaterials(JSON.stringify(rows));
  const actual=api.advanceCompact(text,config,JSON.stringify(links));
  if(actual.length!==expected.length||actual.some((value,i)=>!Object.is(value,expected[i])))throw Error('Physics mismatch at case '+checks);
  checks++;
 }
 return expected;
}
function body(i){
 const cell=i%5===0,virus=i%5!==0&&i%5!==4,box=cell&&i%10===0,angle=Math.fround((random()-.5)*6);
 const mass=.3+random()*3,inertia=mass*(box?600:50);
 return [Math.fround((random()-.5)*600),Math.fround((random()-.5)*500),Math.fround((random()-.5)*100),Math.fround((random()-.5)*100),(random()-.5)*4,cell?18:virus?10:13,+box,+cell,+virus,1/mass,1/inertia,.2,virus||cell?i+1:-2-i,Math.fround(Math.cos(angle)),Math.fround(Math.sin(angle)),1,angle,0,0,0,0,8,300,mass,1,1,250,8,inertia,Math.exp(-1/60),Math.exp(-1/60)];
}
// Changing membership/IDs/order/shape/materials must not reuse stale candidates.
for(const count of [0,1,10,40,120,240]){
 let rows=Array.from({length:count},(_,i)=>body(i));
 for(let tick=0;tick<80;tick++){
  const groups={};
  for(let i=0;i<rows.length;i++){
   const r=rows[i];
   r[0]=Math.fround(r[0]+(tick%4===0?100:.2));
   r[1]=Math.fround(r[1]+(tick%7===0?-97:.1));
   r[15]=(i+tick)%7!==0?1:0;
   r[19]=(i+tick)%17===0?1:0;r[20]=(i+tick)%19===0?1:0;
   r[12]=i%3===0?-2-i:i+1+(tick%2)*1000;
   if(tick%4!==0&&i%3===0)groups[r[12]]=i%2?'same':1;
  }
  compare(rows,groups,1+tick%3);
  compare(rows,groups,1+tick%3); // Exact cache hit, not just invalidation paths.
  if(tick%13===0)rows.reverse();
  if(tick%29===0&&rows.length)rows.pop();
  if(tick%31===0)rows.push(body(rows.length+500));
 }
}
// Two bodies remain in one grid tile while the actual collision changes.
let a=body(5),b=body(1);a[0]=10;a[1]=20;b[0]=80;b[1]=20;
for(const r of [a,b]){r[2]=0;r[3]=0;r[4]=0;r[17]=0;r[18]=0;}
compare([a,b]);b[0]=20;
const contact=compare([a,b]);
if(contact.length<=12)throw Error('An exact contact was skipped on a cache hit');
compare([a,b],{[a[12]]:0,[b[12]]:0});
compare([a,b],{[a[12]]:0,[b[12]]:1});
b[8]=0;b[7]=0;compare([a,b]);
b[7]=1;b[6]=1;compare([a,b]);
compare([a,b],{},2,[[0,1,26]]);
console.log(JSON.stringify({passed:true,comparisons:checks,nativeDecoderAvailable:candidates[0].native,forcedFallback:true}));
