extends RefCounted
# Browser-only graph traversal. Damage, charge, event order and current ownership
# remain in electricity.gd. Coordinates use the same Float32 Vector2 distance.
const SOURCE="""
globalThis.microcosmElectricity = (() => {
 const f=Math.fround, numeric=(a,b)=>a-b;
 function graph(payload) {
  const [rows,reach,currentIds]=JSON.parse(payload);
  const nodes=new Map(), buckets=new Map(), sources=[], currents=new Set(currentIds);
  for(const [id,x,y,source,magnet,charged,virus] of rows) {
   const n={id,x,y,source,magnet,charged,virus,incoming:[],outgoing:[]};nodes.set(id,n);
   if(source)sources.push(id);
   const key=Math.floor(x/reach)+','+Math.floor(y/reach);
   if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(id);
  }
  const queue=sources.slice(), seen=new Set(), active=[];
  for(let cursor=0;cursor<queue.length;cursor++) {
   const id=queue[cursor];if(seen.has(id))continue;seen.add(id);
   if(currents.has(id))active.push(id);
   const n=nodes.get(id),bx=Math.floor(n.x/reach),by=Math.floor(n.y/reach),targets=[];
   for(let x=-1;x<=1;x++)for(let y=-1;y<=1;y++) {
    for(const other of buckets.get((bx+x)+','+(by+y))||[]) {
     if(other===id)continue;
     const m=nodes.get(other),dx=f(n.x-m.x),dy=f(n.y-m.y);
     if(f(f(dx*dx)+f(dy*dy))<reach*reach)targets.push(other);
    }
   }
   targets.sort(numeric);
   for(const other of targets) {
    if(n.incoming.includes(other)||n.outgoing.includes(other))continue;
    const m=nodes.get(other);let outgoing=false;
    if(m.source&&m.charged) {
     if(n.source&&n.charged&&!(!n.magnet&&m.magnet))continue;
     outgoing=true;
    }
    const a=outgoing?n:m,b=outgoing?m:n;
    a.outgoing.push(b.id);b.incoming.push(a.id);queue.push(other);
   }
  }
  function drawToward(id) {
   const origin=nodes.get(id),seen=new Set();let queue=[id],found=false;
   while(queue.length&&!found) {
    const next=[];
    for(const here of queue) {
     if(seen.has(here))continue;seen.add(here);
     if(currents.has(here)&&(here!==id||!origin.source))found=true;
     const n=nodes.get(here),neighbors=n.outgoing.slice();
     if(origin.source)for(const x of n.incoming)if(!neighbors.includes(x))neighbors.push(x);
     neighbors.sort(numeric);
     for(const other of neighbors) {
      if(seen.has(other))continue;next.push(other);
      const m=nodes.get(other),out=n.outgoing.indexOf(other),into=m.incoming.indexOf(here);
      if(out>=0)n.outgoing.splice(out,1);
      if(!n.incoming.includes(other))n.incoming.push(other);
      if(into>=0)m.incoming.splice(into,1);
      if(!m.outgoing.includes(here))m.outgoing.push(here);
     }
    }
    queue=next;
   }
  }
  for(const id of sources)if(nodes.get(id).magnet)drawToward(id);
  for(const [id,n] of nodes)if(n.virus)drawToward(id);
  // Only the lowest outgoing ID and empty/nonempty state are consumed next.
  return JSON.stringify([active,Array.from(nodes.values(),n=>n.outgoing.length?Math.min(...n.outgoing):-1)]);
 }
 return {graph};
})();
"""
