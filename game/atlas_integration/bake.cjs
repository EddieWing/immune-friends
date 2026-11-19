// Offline raster adapter for the original procedural atlas. No browser automation.
const fs=require('fs'),path=require('path'),vm=require('vm');
const {createCanvas}=require(process.env.CANVAS_MODULE||'@napi-rs/canvas');
const root=__dirname,src=path.join(root,'source'),out=path.join(root,'../assets/atlas_integration');
const entries=require('./source/atlas-data.json').entries,rules=require('./source/organelle-rules.json').rules;
const context={console,require:require('module').createRequire(path.join(src,'living-engine.js')),document:{createElement:()=>createCanvas(512,512),getElementById:()=>({checked:false})}};
vm.createContext(context);
for(const name of ['face-morph','bond-gesture','living-catalog','living-features','living-engine']){let code=fs.readFileSync(path.join(src,name+'.js'),'utf8');if(name==='living-features')code=code.replace('if(flight>=0&&s.shot','if(false&&s.shot');vm.runInContext(code,context);}
let renderer=fs.readFileSync(path.join(src,'living-renderer.js'),'utf8');
renderer=renderer.slice(0,renderer.indexOf('function setupCanvas'))+'globalThis.Bake={pigment,organelleTile,renderRig,renderActor};})();';
// Projectiles are drawn by the simulation, never baked into the actor's sprite.
renderer=renderer.replace('if(s.bullet>=0)','if(false)');
renderer=renderer.replace(/function mesh\(ctx,a,lod\)\{[\s\S]*?(?=function curve)/, `function mesh(ctx,a,lod){ctx.save();if(a.spec.id==='virus_basic')ctx.rotate(a.phase*.4);ctx.drawImage(a.texture,-150,-150,300,300);ctx.restore();}\n`);
vm.runInContext(renderer,context);
const L=vm.runInContext('Living',context),B=context.Bake;
const common={idle:'idle',expression:'expression',hurt:'hurt',death:'death'};
const specific={virus_basic:{ability_1:'move',ability_2:'contact',tagged:'tagged'},virus_avoider:{move_core:'move',ability_1:'evade',ability_2:'return',tagged:'tagged'},virus_swarmer:{move_target:'move',ability_1:'swarm',ability_2:'attach',tagged:'tagged'},wall:{placement:'placement',merge:'merge',ability_1:'brace',ability_2:'recover',bond_form:'bond'},turret:{placement:'placement',merge:'merge',ability_1:'aim',ability_2:'shoot',bond_form:'bond'}};
const manifest={schema:1,tile:128,columns:8,fps:12,frames:72,seconds:6,characters:{},faces:L.faceMorph.poses,reactions:L.reactions};
fs.mkdirSync(out,{recursive:true});
const progressPath=path.join(root,'../../.build/atlas-bake-progress.json');
fs.mkdirSync(path.dirname(progressPath),{recursive:true});
const progress=fs.existsSync(progressPath)?JSON.parse(fs.readFileSync(progressPath)):{};
const previous=fs.existsSync(path.join(out,'manifest.json'))?JSON.parse(fs.readFileSync(path.join(out,'manifest.json'))):null;
for(const spec of L.specs){
 if(process.argv.includes('--resume')&&progress[spec.id]){manifest.characters[spec.id]=progress[spec.id];continue;}
 const entry=entries.find(e=>e.id===spec.id),plans={};
 for(const p of entry.animations){const mode=L.catalog.configs[entry.id]?L.catalog.profile(entry,p):({...common,...specific[entry.id]})[p.id];if(!mode)throw Error('Unmapped '+entry.id+':'+p.id);plans[p.id]={mode,title:p.title,trigger:p.trigger};}
 const modes=[...new Set(['idle','move','hurt','death',...Object.values(plans).map(p=>p.mode)])];
 manifest.characters[spec.id]={name:spec.name,face:spec.face,width:spec.width,no_mouth:!!spec.noMouth||spec.id==='turret',plans,modes,body_bounds:[]};
 const protectedModes=spec.id==='wall'?['idle','recover']:[];manifest.characters[spec.id].protected_modes=protectedModes;manifest.characters[spec.id].protected_face=previous?.characters[spec.id]?.protected_face||previous?.characters[spec.id]?.face;manifest.characters[spec.id].frame_faces={...(previous?.characters[spec.id]?.frame_faces||{})};
 const selected=process.argv.find(v=>v.startsWith('--only='))?.slice(7).split(',');
 const needs=mode=>!protectedModes.includes(mode)&&(!selected||selected.includes(spec.id+':*')||selected.includes(spec.id+':'+mode))&&(process.argv.includes('--force')||(process.argv.includes('--refresh-shots')&&L.catalog.shotModes.has(mode))||!fs.existsSync(path.join(out,spec.id+'--'+mode+'.png')));
 if(!modes.some(needs)){if(previous?.characters[spec.id])manifest.characters[spec.id]=previous.characters[spec.id];continue;}
 const seed=L.create(spec,rules);manifest.characters[spec.id].body_bounds=seed.poly;manifest.characters[spec.id].face=seed.spec.face;manifest.characters[spec.id].color=spec.color;manifest.characters[spec.id].edge=spec.edge;
 for(const mode of modes){
  const filename=path.join(out,spec.id+'--'+mode+'.png');if(!needs(mode))continue;
  const a=JSON.parse(JSON.stringify(seed));a.production=true;a.texture=B.pigment(spec);a.tiles=Object.fromEntries(a.org.map(o=>[o.id,B.organelleTile(o.id,spec)]));a.hideFace=true;
  manifest.characters[spec.id].frame_faces[mode]=[];const sheet=createCanvas(1024,1152),ctx=sheet.getContext('2d');
  if(['hurt','impact','contact','shoot','ability'].includes(mode))L.event(a,mode==='shoot'?'ability':'impact');
  for(let f=0;f<72;f++){
   for(let j=0;j<5;j++)L.update(a,1/60,mode,'auto',[1,-.15]);
   // Runtime bonds follow real endpoints. Bake only membrane intention.
   a.bond=null;
   ctx.save();ctx.beginPath();ctx.rect(f%8*128,Math.floor(f/8)*128,128,128);ctx.clip();
   B.renderActor(ctx,a,f%8*128+64,Math.floor(f/8)*128+64,88,false);let face=L.faceLayout(a),life=L.lifecycle(a);manifest.characters[spec.id].frame_faces[mode].push([face[0]*life.scale,face[1]*life.scale,face[2]*life.scale,life.faceAlpha]);ctx.restore();
  }
  fs.writeFileSync(filename,sheet.toBuffer('image/png'));
 }
 progress[spec.id]=manifest.characters[spec.id];fs.writeFileSync(progressPath,JSON.stringify(progress));
 console.log(spec.id,modes.length,'clips');

}
fs.writeFileSync(path.join(out,'manifest.json.tmp'),JSON.stringify(manifest));
fs.renameSync(path.join(out,'manifest.json.tmp'),path.join(out,'manifest.json'));
console.log('DONE',Object.keys(manifest.characters).length,'characters');
