import json,struct,shutil
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'environments/foret_des_lueurs'
removed=json.loads((SOURCE/'stairs_removed_trees.json').read_text())
BACKUP=SOURCE/'stairs_backup_20261017';BACKUP.mkdir(exist_ok=True)
def read(path):
 raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0];d=json.loads(raw[20:20+size]);p=20+size;n=struct.unpack_from('<I',raw,p)[0];return d,bytearray(raw[p+8:p+8+n])
def arr(d,b,i):
 a=d['accessors'][i];v=d['bufferViews'][a['bufferView']];dim={'SCALAR':1,'VEC3':3}[a['type']];dt={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']];return np.frombuffer(b,dtype=dt,count=a['count']*dim,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,dim).copy()
for backup in BACKUP.glob('tile_*.glb'): shutil.copy2(backup,ROOT/'godot/assets/environment/world'/backup.name)
report=[]
for tile in sorted({name.split('_',1)[1].rsplit('_',1)[0] for name in removed}):
 path=ROOT/'godot/assets/environment/world'/('tile_'+tile.lower()+'.glb')
 backup=BACKUP/path.name
 if not backup.exists():shutil.copy2(path,backup)
 d,b=read(backup);total=0
 for node in d['nodes']:
  name=node.get('name','');kind='Wood' if name.startswith('Wood') else 'Leaves' if name.startswith('Leaves') else None
  if kind is None or 'mesh' not in node:continue
  wanted={tuple(round(float(q),3) for q in (p[0],p[2],-p[1])) for n,verts in removed.items() if n.startswith(kind+'_'+tile+'_') for p in verts}
  if not wanted:continue
  matrix=np.array(node['matrix']).reshape(4,4).T if 'matrix' in node else np.eye(4)
  if 'matrix' not in node:matrix[:3,3]=node.get('translation',[0,0,0])
  count=0
  for prim in d['meshes'][node['mesh']]['primitives']:
   xyz=arr(d,b,prim['attributes']['POSITION']);world=xyz@matrix[:3,:3].T+matrix[:3,3]
   ids=arr(d,b,prim['indices']).reshape(-1,3)
   flags=np.array([tuple(round(float(q),3) for q in p) in wanted for p in world])
   erase=flags[ids].all(axis=1);count+=int(erase.sum())
   kept=ids[~erase].astype('<u4').ravel();b+=b'\0'*((-len(b))%4);offset=len(b);b.extend(kept.tobytes())
   vi=len(d['bufferViews']);d['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':kept.nbytes,'target':34963})
   ai=len(d['accessors']);d['accessors'].append({'bufferView':vi,'componentType':5125,'count':len(kept),'type':'SCALAR'});prim['indices']=ai
  report.append({'tile':tile,'node':name,'removed_triangles':count});total+=count
  assert count>0,(tile,kind,'No matching vertices')
 assert total>0
 b+=b'\0'*((-len(b))%4);d['buffers'][0]['byteLength']=len(b)
 js=json.dumps(d,ensure_ascii=False,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
 path.write_bytes(struct.pack('<III',0x46546c67,2,28+len(js)+len(b))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(b),0x004e4942)+b)
(SOURCE/'stairs_tree_removal_report.json').write_text(json.dumps(report,indent=2));print(report)

