from PIL import Image
from pathlib import Path
import numpy as np,json
base=Path(__file__).resolve().parent.parent/'assets/hero/motion-audit-v3'
manifest={}
for source in sorted(base.glob('*carry-upper-source.png')):
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
 large=sorted([g for g in groups.values() if g[1]>1700],key=lambda g:g[1],reverse=True)[:4]
 if len(large)!=4:raise SystemExit('Expected four upper-body parts')
 large.sort(key=lambda g:(g[0][1]+g[0][3])/2)
 ordered=[]
 for row in range(2):ordered+=sorted(large[row*2:(row+1)*2],key=lambda g:(g[0][0]+g[0][2])/2)
 records=[]
 pixels=np.asarray(image)
 for (left,top,right,bottom),count in ordered:
  r=[max(0,left-2),max(0,top-2),right-left+4,bottom-top+4]
  crop=pixels[r[1]:r[1]+r[3],r[0]:r[0]+r[2]]
  rgb=crop[:,:,:3].astype(float)/255;alpha=crop[:,:,3]>160
  blue=alpha&(rgb[:,:,1]>rgb[:,:,0]*1.15)&(rgb[:,:,2]>rgb[:,:,0]*1.10)&(rgb[:,:,1]>.16)
  yy,xx=np.where(blue)
  hem=int(np.quantile(yy,.995));band=(yy>hem-20)
  anchor=float(np.median(xx[band]))
  dark=alpha&(rgb.max(2)<.28)&((rgb.max(2)-rgb.min(2))<.06)&(rgb.max(2)>.035)
  density=dark[:int(crop.shape[0]*.7)].sum(1)
  dense=np.where(density>=max(12,r[2]*.035))[0]
  hair=int(dense[0]) if len(dense) else 0
  records.append({'rect':r,'hem':hem,'anchor':anchor,'body_height':hem-hair})
 manifest[name]=records
 print(name,records)
(base/'upper-regions.json').write_text(json.dumps(manifest,indent=2)+'\n')
