#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <limits>
#include <algorithm>
#include <cmath>
#include <vector>
#include <cstdio>
#include <emscripten.h>
#include <cstdint>
#include <string>
using namespace godot;
namespace {
struct V { float x,y; };
V add(V a,V b){return {float(a.x+b.x),float(a.y+b.y)};}
V sub(V a,V b){return {float(a.x-b.x),float(a.y-b.y)};}
V mul(V a,double k){const float s=float(k);return {float(a.x*s),float(a.y*s)};}
V divv(V a,double k){const float s=float(k);return {float(a.x/s),float(a.y/s)};}
float squared(V a){return float(float(a.x*a.x)+float(a.y*a.y));}
float length(V a){return float(std::sqrt(double(squared(a))));}
V limit(V a,float max){const float n=length(a);return n>0&&max<n?mul(divv(a,n),max):a;}
}
class CoreKernel : public RefCounted {
 GDCLASS(CoreKernel,RefCounted);
protected:
 static void _bind_methods(){ClassDB::bind_method(D_METHOD("nearest_cores", "viruses", "cores", "living"), &CoreKernel::nearest_cores);ClassDB::bind_method(D_METHOD("radar_last", "flags", "links", "roots"), &CoreKernel::radar_last);ClassDB::bind_method(D_METHOD("local_projectile_start","bodies","items","config"),&CoreKernel::local_projectile_start);ClassDB::bind_method(D_METHOD("local_projectile_next","changed","alive","tag","extra","capacity"),&CoreKernel::local_projectile_next);ClassDB::bind_method(D_METHOD("local_graph","payload"),&CoreKernel::local_graph);ClassDB::bind_method(D_METHOD("local_init","source"),&CoreKernel::local_init);ClassDB::bind_method(D_METHOD("local_materials","json"),&CoreKernel::local_materials);ClassDB::bind_method(D_METHOD("local_advance","rows","config","links"),&CoreKernel::local_advance);ClassDB::bind_method(D_METHOD("local_probe"),&CoreKernel::local_probe);ClassDB::bind_method(D_METHOD("step","rows","links","count","dt","drift","stiffness","decay"),&CoreKernel::step);}
public:
 PackedInt32Array nearest_cores(const PackedVector2Array &viruses,const PackedVector2Array &cores,const PackedInt32Array &living) {
  PackedInt32Array result;if(cores.size()!=living.size())return result;
  result.resize(viruses.size());const Vector2 *v=viruses.ptr(),*c=cores.ptr();const int32_t *alive=living.ptr();int32_t *out=result.ptrw();
  for(int i=0;i<viruses.size();i++){float best=std::numeric_limits<float>::infinity();int chosen=-1;
   for(int j=0;j<cores.size();j++){float dx=float(v[i].x-c[j].x),dy=float(v[i].y-c[j].y),dist=float(float(dx*dx)+float(dy*dy));if(dist<best && alive[j]){best=dist;chosen=j;}}
   out[i]=chosen;
  }return result;
 }
 PackedInt32Array radar_last(const PackedInt32Array &flags, const PackedInt32Array &links, const PackedInt32Array &roots) {
  PackedInt32Array out;const int n=flags.size();if(links.size()%2)return out;
  const int32_t *fl=flags.ptr(),*edges=links.ptr(),*starts=roots.ptr();std::vector<std::vector<int>> adj(n);
  for(int i=0;i<links.size();i+=2){int a=edges[i],b=edges[i+1];if(a<0||b<0||a>=n||b>=n)return PackedInt32Array();adj[a].push_back(b);if(a!=b)adj[b].push_back(a);}
  out.resize(roots.size());int32_t *dst=out.ptrw();std::vector<int> seen(n,0),queue;int generation=0;
  for(int i=0;i<roots.size();i++){
   int source=starts[i];if(source<0||source>=n)return PackedInt32Array();dst[i]=-1;if(!(fl[source]&1))continue;
   ++generation;queue.clear();queue.push_back(source);seen[source]=generation;
   for(size_t q=0;q<queue.size();q++){
    int here=queue[q];if(here!=source&&(fl[here]&2))dst[i]=here;
    for(int next:adj[here])if(seen[next]!=generation&&(fl[next]&1)){seen[next]=generation;queue.push_back(next);}
   }
  }
  return out;
 }



 void local_projectile_start(const String &bodies,const String &items,const String &config){CharString b=bodies.utf8(),i=items.utf8(),c=config.utf8();char code[512];std::snprintf(code,sizeof(code),"globalThis.microcosmContacts.projectileStart(UTF8ToString(%u),UTF8ToString(%u),UTF8ToString(%u))",unsigned(reinterpret_cast<uintptr_t>(b.get_data())),unsigned(reinterpret_cast<uintptr_t>(i.get_data())),unsigned(reinterpret_cast<uintptr_t>(c.get_data())));emscripten_run_script(code);}
 PackedFloat64Array local_projectile_next(int changed,int alive,int tag,const String &extra,int capacity){
  PackedFloat64Array out;if(capacity<=0)return out;out.resize(capacity*10);double *output=out.ptrw();CharString e=extra.utf8();char code[512];
  std::snprintf(code,sizeof(code),"(()=>{const v=globalThis.microcosmContacts.projectileNext(%d,%d,%d,UTF8ToString(%u));if(v.length>%d)return -1;HEAPF64.set(v,%u/8);return v.length})()",changed,alive,tag,unsigned(reinterpret_cast<uintptr_t>(e.get_data())),capacity*10,unsigned(reinterpret_cast<uintptr_t>(output)));
  int used=emscripten_run_script_int(code);if(used<0||used>capacity*10){out.clear();return out;}out.resize(used);return out;
 }
 String local_graph(const String &payload){CharString p=payload.utf8();char code[256];std::snprintf(code,sizeof(code),"globalThis.microcosmElectricity.graph(UTF8ToString(%u))",unsigned(reinterpret_cast<uintptr_t>(p.get_data())));const char *result=emscripten_run_script_string(code);return result?String::utf8(result):String();}
 void local_init(const String &source){CharString s=source.utf8();emscripten_run_script(s.get_data());}
 void local_materials(const String &json){CharString s=json.utf8();char code[256];std::snprintf(code,sizeof(code),"globalThis.microcosmContacts.setMaterials(UTF8ToString(%u))",unsigned(reinterpret_cast<uintptr_t>(s.get_data())));emscripten_run_script(code);}
 PackedFloat64Array local_advance(const PackedFloat64Array &rows,const String &config,const String &links){
  PackedFloat64Array out;int n=rows.size()/13;if(rows.size()%13||n==0)return out;
  int max_values=n*6+n*(n-1);out.resize(max_values);const double *input=rows.ptr();double *output=out.ptrw();
  CharString c=config.utf8(),l=links.utf8();char code[1024];
  std::snprintf(code,sizeof(code),"(()=>{const v=globalThis.microcosmContacts.advanceArray(new Float64Array(HEAPU8.buffer,%u,%d),UTF8ToString(%u),UTF8ToString(%u));if(v.length>%d)return -1;HEAPF64.set(v,%u/8);return v.length})()",unsigned(reinterpret_cast<uintptr_t>(input)),int(rows.size()),unsigned(reinterpret_cast<uintptr_t>(c.get_data())),unsigned(reinterpret_cast<uintptr_t>(l.get_data())),max_values,unsigned(reinterpret_cast<uintptr_t>(output)));
  int used=emscripten_run_script_int(code);if(used<0||used>max_values){out.clear();return out;}out.resize(used);return out;
 }
 int local_probe(){return emscripten_run_script_int("(globalThis.__mc125_probe=(globalThis.__mc125_probe||0)+1), (typeof document==='undefined'?1000:0)+globalThis.__mc125_probe");}
 PackedFloat32Array step(const PackedFloat64Array &rows,const PackedInt32Array &links,int count,double dt,double drift,double stiffness,double decay){
  PackedFloat32Array out;
  const int n=rows.size()/7;
  if(rows.size()%7||links.size()%2||count<0)return out;
  const double *r=n?rows.ptr():nullptr;const int32_t *edges=links.size()?links.ptr():nullptr;
  for(int k=0;k<links.size();k++)if(edges[k]<0||edges[k]>=n)return out;
  std::vector<V> positions(n),velocities(n),normals(n),forces(n);
  std::vector<bool> alive(n);
  for(int i=0;i<n;i++){positions[i]={float(r[i*7]),float(r[i*7+1])};alive[i]=r[i*7+2]!=0;velocities[i]={float(r[i*7+3]),float(r[i*7+4])};normals[i]={float(r[i*7+5]),float(r[i*7+6])};}
  for(int step=0;step<count;step++){
   V center{0,0};int living=0;
   for(int i=0;i<n;i++)if(alive[i]){center=add(center,positions[i]);living++;}
   if(living){center=divv(center,living);const V offset=mul(center,drift);for(int i=0;i<n;i++)if(alive[i])positions[i]=add(positions[i],offset);}
   std::fill(forces.begin(),forces.end(),V{0,0});
   for(int k=0;k<links.size();k+=2){const int a=edges[k],b=edges[k+1];if(!alive[a]||!alive[b])continue;const V offset=sub(positions[b],positions[a]);const float distance=length(offset);if(distance<.001)continue;
    const V force=mul(mul(divv(offset,distance),double(distance)-26),stiffness);forces[a]=add(forces[a],force);forces[b]=sub(forces[b],force);
   }
   for(int i=0;i<n;i++)if(alive[i]){
    velocities[i]=limit(mul(add(velocities[i],mul(forces[i],dt)),decay),650);
    const V next=add(positions[i],mul(velocities[i],dt));positions[i]={std::max(-550.f,std::min(550.f,next.x)),std::max(-300.f,std::min(280.f,next.y))};
   }
   for(int pass=0;pass<8;pass++)for(int i=0;i<n;i++)if(alive[i])for(int j=i+1;j<n;j++)if(alive[j]){
    const V offset=sub(positions[j],positions[i]);const float sq=squared(offset);if(sq>=676)continue;const float distance=float(std::sqrt(double(sq)));if(distance>=26)continue;
    const V normal=distance>.001?divv(offset,distance):normals[i];const V correction=divv(mul(normal,26.0-double(distance)),2);
    positions[i]=sub(positions[i],correction);positions[j]=add(positions[j],correction);
   }
  }
  out.resize(n*4);float *dst=n?out.ptrw():nullptr;
  for(int i=0;i<n;i++){dst[i*4]=positions[i].x;dst[i*4+1]=positions[i].y;dst[i*4+2]=velocities[i].x;dst[i*4+3]=velocities[i].y;}
  return out;
 }
};
void initialize_core(ModuleInitializationLevel level){if(level==MODULE_INITIALIZATION_LEVEL_SCENE)GDREGISTER_CLASS(CoreKernel);}
void uninitialize_core(ModuleInitializationLevel){}
extern "C" GDExtensionBool GDE_EXPORT core_kernel_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *init){
 GDExtensionBinding::InitObject object(get_proc,library,init);object.register_initializer(initialize_core);object.register_terminator(uninitialize_core);object.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return object.init();
}
