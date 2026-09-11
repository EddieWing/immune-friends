import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.join(path.dirname(fileURLToPath(import.meta.url)),'web');
const types={'.html':'text/html; charset=utf-8','.js':'application/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml'};
http.createServer((req,res)=>{
 let filename;
 try { filename=path.resolve(root,'.'+decodeURIComponent(new URL(req.url,'http://localhost').pathname)); }
 catch {res.writeHead(400).end();return;}
 if(filename===root) filename=path.join(root,'index.html');
 if(!filename.startsWith(root+path.sep)){res.writeHead(403).end();return;}
 fs.stat(filename,(error,stat)=>{
  if(error||!stat.isFile()){res.writeHead(404).end('Not found');return;}
  res.writeHead(200,{'Content-Type':types[path.extname(filename)]||'application/octet-stream','Content-Length':stat.size,'Cache-Control':'no-cache'});
  fs.createReadStream(filename).pipe(res);
 });
}).listen(8060,'127.0.0.1',()=>console.log('Game: http://127.0.0.1:8060'));
