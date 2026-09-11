import fs from 'node:fs/promises';
import {inflateRawSync} from 'node:zlib';
const url='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz';
async function range(start,end){
 const response=await fetch(url,{headers:{Range:`bytes=${start}-${end}`}});
 if(response.status!==206) throw new Error(`Range request failed: ${response.status}`);
 return Buffer.from(await response.arrayBuffer());
}
const size=1281349702;
const tail=await range(size-65557,size-1);
const eocd=tail.lastIndexOf(Buffer.from([0x50,0x4b,0x05,0x06]));
if(eocd<0) throw new Error('Missing ZIP directory');
const offset=tail.readUInt32LE(eocd+16), length=tail.readUInt32LE(eocd+12);
const directory=await range(offset,offset+length-1);
await fs.mkdir('game/export-templates',{recursive:true});
for(let p=0;p<directory.length;){
 if(directory.readUInt32LE(p)!==0x02014b50) break;
 const method=directory.readUInt16LE(p+10), compressed=directory.readUInt32LE(p+20);
 const nameLength=directory.readUInt16LE(p+28),extra=directory.readUInt16LE(p+30),comment=directory.readUInt16LE(p+32);
 const name=directory.subarray(p+46,p+46+nameLength).toString();
 if(/web.*(nothreads|release).*\.zip$/.test(name)){
  console.log(name,compressed);
  if(name.endsWith('web_nothreads_release.zip')){
   const localOffset=directory.readUInt32LE(p+42);
   const header=await range(localOffset,localOffset+29);
   const start=localOffset+30+header.readUInt16LE(26)+header.readUInt16LE(28);
   const content=await range(start,start+compressed-1);
   await fs.writeFile('game/export-templates/web_nothreads_release.zip',method===8?inflateRawSync(content):content);
  }
 }
 p+=46+nameLength+extra+comment;
}
