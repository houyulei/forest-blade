from PIL import Image
from pathlib import Path
import numpy as np,json
base=Path(__file__).resolve().parent.parent/'assets/hero/weapon-redesign'
manifest={}
for source in sorted(base.glob('*-source.png')):
 name=source.name.removesuffix('-source.png');cols=6
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
 large=sorted([g for g in groups.values() if g[1]>2500],key=lambda g:g[1],reverse=True)[:cols*4]
 print(name,'components',len(large),[g[0] for g in large])
 if name=='greatsword-attack' and len(large)==23:
  # Source cut 4 and its neighbor's scarf touch in the right-facing row.
  # Hold the clean right-facing release from row 2, rather than include another body.
  clean=[g for g in large if g[0][2]-g[0][0]<450]
  rows=[sorted([g for g in clean if int(((g[0][1]+g[0][3])/2)/256)==row],key=lambda g:(g[0][0]+g[0][2])/2) for row in range(4)]
  release=rows[1][3]
  rows[2]=rows[2][:3]+[release,release]+rows[2][3:]
  ordered=[g for row in rows for g in row]
 else:
  if len(large)!=cols*4:raise SystemExit('Unexpected connected components: inspect artwork')
  large.sort(key=lambda g:(g[0][1]+g[0][3])/2)
  ordered=[]
  for row in range(4):ordered+=sorted(large[row*cols:(row+1)*cols],key=lambda g:(g[0][0]+g[0][2])/2)
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
 manifest[name]=frames
(base/'regions.json').write_text(json.dumps(manifest,indent=2)+'\n')
