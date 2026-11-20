const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const c=vm.createContext({atob});vm.runInContext(fs.readFileSync(__dirname+'/../scripts/web_physics.gd','utf8').split('"""')[1],c);
const r=[700,0,0,0,0,18,1,1,0,1,1,.2,1,1,0,1,0,0,0,0,0,8,300,1,1,1,250,8,1,1,1];
let battle=c.microcosmContacts.advance([r.slice()],1/60,1,1,[],0,0,{},false);
let prep=c.microcosmContacts.advance([r.slice()],1/60,1,1,[],0,0,{},true);
assert(battle[0]>690);assert(prep[0]<620);console.log('PASS: web source area unbounded in battle, preparation bounded');
