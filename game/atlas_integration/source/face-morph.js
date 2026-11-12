/* Shared face topology. Coordinates are normalized by face width, never sprite scale. */
const FaceMorph=(()=>{
 const names=['calm','angry','hurt','laugh','cry','surprised','smirk','kiss','wink','blush','worried','spiral','raised_brow','relieved','pensive','confused','astonished','weary'];
 const tau=Math.PI*2,mix=(a,b,t)=>a+(b-a)*t,quad=(a,b,c,t)=>(1-t)**2*a+2*(1-t)*t*b+t*t*c;
 function eye(name,side){let rx=.174,ry=.221,N=24,top=[],bottom=[];
  const closed=['hurt','laugh','kiss','relieved','pensive','weary'].includes(name)||(name==='wink'&&side===1);
  if(closed){for(let i=0;i<=N;i++){let u=i/N,x=mix(-rx*.85,rx*.85,u),y=quad(.015,name==='pensive'?ry*.3:name==='hurt'?-.035:name==='weary'?-.04:-ry*.35,.015,u);if(name==='hurt')x*=-side;top.push([x,y])}bottom=[...top].reverse();}
  else if(name==='angry'||name==='smirk'){
   let m=name==='angry'?-side*.32:0,b=name==='angry'?-ry*.42:-ry*.15,A=1/(rx*rx)+m*m/(ry*ry),B=2*m*b/(ry*ry),C=b*b/(ry*ry)-1,D=Math.sqrt(B*B-4*A*C),xl=(-B-D)/(2*A),xr=(-B+D)/(2*A),yl=m*xl+b,yr=m*xr+b;
   for(let i=0;i<=N;i++){let u=i/N;top.push([mix(xl,xr,u),name==='smirk'?quad(yl,-ry*.4,yr,u):mix(yl,yr,u)])}
   let ar=Math.atan2(yr/ry,xr/rx),al=Math.atan2(yl/ry,xl/rx);while(al<ar)al+=tau;
   for(let i=0;i<=N;i++){let angle=mix(ar,al,i/N);bottom.push([Math.cos(angle)*rx,Math.sin(angle)*ry])}
  }else{for(let i=0;i<=N;i++){let angle=Math.PI+i/N*Math.PI;top.push([Math.cos(angle)*rx,Math.sin(angle)*ry]);angle=i/N*Math.PI;bottom.push([Math.cos(angle)*rx,Math.sin(angle)*ry])}}
  // Every contour starts at its left landmark, including the mirrored Hurt stroke.
  if(top[0][0]>top[top.length-1][0]){top.reverse();bottom.reverse()}
  return top.concat(bottom);
 }
 function brow(name,side){let rx=.174,ry=.221,raised=['surprised','astonished','blush'].includes(name),sad=['cry','worried','pensive','weary'].includes(name),y=-ry*(raised?1.7:1.35)+(name==='raised_brow'?(side===1?-ry*.5:ry*.2):0);if(name==='hurt')y=-ry*.38;
  return Array.from({length:25},(_,i)=>{let u=i/24;return [mix(-rx*.8,rx*.8,u),quad(y-(sad?side*ry*.25:0),y-ry*.16,y+(sad?side*ry*.25:0),u)]});
 }
 function mouth(name){let y=name==='laugh'?.28:.4,w=name==='laugh'?.20:.17,top=[],bottom=[];
  for(let i=0;i<=32;i++){let u=i/32,x=(u*2-1)*w,base=y,thick=0;
   if(name==='laugh'){base=y+.025*(1-(u*2-1)**2);thick=.13*Math.sin(u*Math.PI)}
   else if(['surprised','astonished'].includes(name)){let r=name==='astonished'?.75:.44;x*=r;let h=(name==='astonished'?.14:.09)*Math.sqrt(Math.max(0,1-(u*2-1)**2));base=y-h;thick=h*2}
   else if(name==='weary'){base=y+.06-.15*Math.sin(Math.PI*u);thick=.12*Math.sin(Math.PI*u)}
   else if(name==='kiss'){x=.028*Math.sin(u*Math.PI*2)-.01;base=y+(u-.5)*.14}
   else if(name==='hurt'||name==='spiral')base=y+Math.cos((u*2-1)*tau*(name==='hurt'?1:.75))*.025;
   else if(['cry','worried','pensive'].includes(name))base=y+.04-.09*Math.sin(u*Math.PI);
   else if(name==='confused')base=y+.025*(1-u)-.035*u+.025*Math.sin(u*tau);
   else if(name==='raised_brow')base=y-u*.015;
   else base=y+Math.sin(Math.PI*u)*(name==='angry'?.013:.06)-(name==='smirk'?u*.07:0);
   top.push([x,base]);bottom.unshift([x,base+thick]);
  }return top.concat(bottom);
 }
 const poses=Object.fromEntries(names.map(name=>[name,{eyes:[eye(name,-1),eye(name,1)],brows:[brow(name,-1),brow(name,1)],mouth:mouth(name)}]));
 function step(a,target,dt){a.faceWeights??={calm:1};a.faceFast??={...a.faceWeights};let e=Math.exp(-22*dt),next={},fast={};for(let n of names){let t=target[n]||0,f=a.faceFast[n]||0,v=a.faceWeights[n]||0;fast[n]=t+(f-t)*e;next[n]=t+(v-t+(f-t)*22*dt)*e}a.faceFast=fast;a.faceWeights=next;}
 function geometry(weights){let result={eyes:[[],[]],brows:[[],[]],mouth:[]};for(let key of ['eyes','brows','mouth']){let lists=key==='mouth'?[result[key]]:result[key];for(let side=0;side<lists.length;side++){let count=key==='mouth'?66:key==='eyes'?50:25;for(let i=0;i<count;i++){let p=[0,0];for(let n of names){let w=weights[n]||0;if(!w)continue;let q=key==='mouth'?poses[n][key][i]:poses[n][key][side][i];p[0]+=q[0]*w;p[1]+=q[1]*w}lists[side].push(p)}}}return result;}
 return {names,poses,step,geometry};
})();
if(typeof module!=='undefined')module.exports=FaceMorph;
