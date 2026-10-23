from PIL import Image
from pathlib import Path
import numpy as np,json
base=Path(__file__).resolve().parent.parent/'assets/hero/motion-audit-v3'
manifest={}
for source in sorted(base.glob('*-source.png')):
 name=source.name.removesuffix('-source.png');cols=6
 if 'carry-upper' in name: continue
 image=Image.open(source)
 width,height=image.size
 a=np.asarray(image)[:,:,3]>90
 parent=[];boxes=[];sizes=[]
 def find(i):
  while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
  return i
 prev=[]
 for y,row in enumerate(a):
  d=np.diff(np.r_[False,row,False].astype(np.int8));starts=np.where(d==1)[0];ends=np.where(d==-1)[0]
  curr=[];j=0
  for left,right in zip(starts,ends):
   left=int(left);right=int(right);i=len(parent);parent.append(i);boxes.append([left,y,right,y+1]);sizes.append(right-left)
   while j<len(prev) and prev[j][1]<left:j+=1
   k=j
   while k<len(prev) and prev[k][0]<=right:
    old=find(prev[k][2]);new=find(i)
    if old!=new:parent[old]=new
    k+=1
   curr.append((left,right,i))
  prev=curr
 groups={}
 for i,b in enumerate(boxes):
  r=find(i)
  if r not in groups:groups[r]=[b.copy(),0]
  g=groups[r];g[0]=[min(g[0][0],b[0]),min(g[0][1],b[1]),max(g[0][2],b[2]),max(g[0][3],b[3])];g[1]+=sizes[i]
 large=sorted([g for g in groups.values() if g[1]>1700],key=lambda g:(g[0][1]+g[0][3])/2)
 # Group complete alpha islands into visual rows; do not assume a successful model grid.
 rows=[]
 for g in large:
  cy=(g[0][1]+g[0][3])/2
  if not rows or cy-sum((q[0][1]+q[0][3])/2 for q in rows[-1])/len(rows[-1])>height*0.07:
   rows.append([])
  rows[-1].append(g)
 for row in rows: row.sort(key=lambda g:(g[0][0]+g[0][2])/2)
 print(name,'ROW_COUNTS',[len(row) for row in rows],'ROW_Y',[round(sum((q[0][1]+q[0][3])/2 for q in row)/len(row)) for row in rows])
 if len(rows)==8 and all(len(row)==3 for row in rows):
  ordered=[g for row in rows for g in row]
 elif len(rows)==4 and all(len(row)==6 for row in rows):
  ordered=[g for row in rows for g in row]
 elif len(rows)==7 and all(len(row)==3 for row in rows):
  ordered=[g for row in rows[:6] for g in row]+[rows[6][0],rows[6][1],rows[6][1],rows[6][1],rows[6][2],rows[6][2]]
 elif len(rows)==6 and all(len(row)==6 for row in rows):
  # Extra generated rows are alternate near-identical directions; use coherent front/side/back sets.
  ordered=[g for row in [rows[0],rows[2],rows[2],rows[4]] for g in row]
 elif len(rows)==5 and all(len(row)==6 for row in rows):
  ordered=[g for row in [rows[0],rows[2],rows[2],rows[3]] for g in row]
 else: raise SystemExit('Inspect source grid before atlas assembly')
 frames=[]
 for main,count in ordered:
  components=[main]
  for other,n in groups.values():
   if n<20 or any(other==g[0] for g in large):continue
   cx=(other[0]+other[2])/2;cy=(other[1]+other[3])/2
   distances=[max(bb[0]-cx,0,cx-bb[2])**2+max(bb[1]-cy,0,cy-bb[3])**2 for bb,_ in ordered]
   if distances.index(min(distances))==ordered.index([main,count]) and min(distances)<60**2:components.append(other)
  l=min(bb[0] for bb in components);t=min(bb[1] for bb in components);r=max(bb[2] for bb in components);b=max(bb[3] for bb in components)
  frames.append({'rect':[max(0,l-2),max(0,t-2),min(width,r+2)-max(0,l-2),min(height,b+2)-max(0,t-2)],'components':[[bb[0],bb[1],bb[2]-bb[0],bb[3]-bb[1]] for bb in components]})
 # Measure body, not raised weapons: dense neutral-dark hair above the torso.
 pixels=np.asarray(image)
 for row in range(4):
  rec=frames[row*6];x,y,w,h=rec['rect']
  crop=pixels[y:y+h,x:x+w];rgb=crop[:,:,:3].astype(float)/255
  dark=(rgb.max(2)<0.28)&((rgb.max(2)-rgb.min(2))<0.06)&(rgb.max(2)>0.035)&(crop[:,:,3]>160)
  # Hair is a dense band; thin blade outlines and brown gloves are excluded.
  counts=dark[:int(h*0.65)].sum(1)
  dense=np.where(counts>=max(12,w*0.045))[0]
  top=int(dense[0]) if len(dense) else 0
  rec['body_height']=h-top-2
  rec['hair_top']=top
  print('BODY',name,row,rec['body_height'],'source height',h)
 if name=='spear-lunge-v3' and len(rows)==7:
  # Missing back-view release in generated study: use the approved matching rear-grip release.
  import copy
  for column in [2,3,4]:
   frames[18+column]=copy.deepcopy(manifest['spear-guard-v3'][18+column])
   frames[18+column]['source']='spear-guard-v3'
   frames[18+column]['scale_body']=manifest['spear-guard-v3'][18]['body_height']
 manifest[name]=frames
(base/'regions.json').write_text(json.dumps(manifest,indent=2)+'\n')
