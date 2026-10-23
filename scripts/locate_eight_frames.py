"""Analyze alpha and foot/hair registration only; never synthesize or redraw artwork."""
from pathlib import Path
from PIL import Image
import numpy as np, json
base=Path(__file__).resolve().parent.parent/'assets/hero/eight-directions'
manifest={}
for original in sorted(base.glob('*-diagonal-source.png')):
    corrected=original.with_name(original.name.replace('-source.png','-corrected-source.png'))
    path=corrected if corrected.exists() else original
    name=original.name.removesuffix('-source.png')
    p=np.asarray(Image.open(path).convert('RGBA')); h,w=p.shape[:2];frames=[]
    # Connected alpha islands let rows breathe without cutting a weapon at nominal grid boundaries.
    parent=[]; boxes=[]; sizes=[]; prev=[]
    def find(i):
        while parent[i]!=i: parent[i]=parent[parent[i]];i=parent[i]
        return i
    for y,line in enumerate(p[:,:,3]>90):
        d=np.diff(np.r_[False,line,False].astype(np.int8));curr=[];j=0
        for l,r in zip(np.where(d==1)[0],np.where(d==-1)[0]):
            l=int(l);r=int(r);i=len(parent);parent.append(i);boxes.append([l,y,r,y+1]);sizes.append(r-l)
            while j<len(prev) and prev[j][1]<l:j+=1
            k=j
            while k<len(prev) and prev[k][0]<=r:
                old=find(prev[k][2]);new=find(i)
                if old!=new:parent[old]=new
                k+=1
            curr.append((l,r,i))
        prev=curr
    groups={}
    for i,bb in enumerate(boxes):
        root=find(i)
        if root not in groups:groups[root]=[bb.copy(),0]
        g=groups[root];g[0]=[min(g[0][0],bb[0]),min(g[0][1],bb[1]),max(g[0][2],bb[2]),max(g[0][3],bb[3])];g[1]+=sizes[i]
    large=sorted([g for g in groups.values() if g[1]>1700],key=lambda g:(g[0][1]+g[0][3])/2)
    rows=[]
    for g in large:
        cy=(g[0][1]+g[0][3])/2
        if not rows or cy-np.mean([(q[0][1]+q[0][3])/2 for q in rows[-1]])>h*.075: rows.append([])
        rows[-1].append(g)
    overrides={}
    if name=='thunder-attack-1-diagonal' and len(rows)==4 and len(rows[3])==5:
        rows[3].sort(key=lambda g:g[0][0]+g[0][2])
        rows[3]=rows[3][:2]+[rows[3][0],rows[3][0]]+rows[3][-2:]
        overrides={20:('thunder-attack-2-diagonal',20),21:('thunder-attack-2-diagonal',21)}
    if name=='thunder-attack-1-diagonal':overrides[3]=('thunder-attack-2-diagonal',3)
    if name=='thunder-attack-3-diagonal':overrides.update({3:('thunder-attack-2-diagonal',3),4:('thunder-attack-2-diagonal',4)})
    if len(rows)!=4 or any(len(r)!=6 for r in rows): raise ValueError((path.name,'inspect grid',[len(r) for r in rows]))
    for row in range(4):
        body=[]
        if not (name=='thunder-attack-1-diagonal' and row==3 and 20 in overrides): rows[row].sort(key=lambda g:g[0][0]+g[0][2])
        for col,(box,count) in enumerate(rows[row]):
            x0=max(0,box[0]-2);x1=min(w,box[2]+2);y0=max(0,box[1]-2);y1=min(h,box[3]+2)
            q=p[y0:y1,x0:x1];rgb=q[:,:,:3].astype(float)/255;alpha=q[:,:,3]>90
            ys,xs=np.where(alpha)
            if not len(xs):raise ValueError((path.name,row,col,'empty cell'))
            dark=(rgb.max(2)<.29)&(rgb.max(2)-rgb.min(2)<.12)&(rgb.max(2)>.035)&alpha
            dense=np.where(dark.sum(1)>=max(8,q.shape[1]*.04))[0]
            hair=int(dense[0]) if len(dense) else int(ys.min())
            brown=(rgb[:,:,0]>rgb[:,:,1]*1.12)&(rgb[:,:,0]<rgb[:,:,1]*2.2)&(rgb[:,:,1]>rgb[:,:,2]*1.1)&(rgb[:,:,0]<.75)&alpha
            brown[:int(hair+(ys.max()-hair)*.68)]=False
            by,bx=np.where(brown)
            bottom=int(by.max())+1 if len(by) else int(ys.max())+1
            feet=brown.copy();feet[:max(0,bottom-24)]=False
            fy,fx=np.where(feet)
            pivot=float(np.median(fx)) if len(fx) else float(np.median(xs))
            body.append(bottom-hair)
            frames.append({'source_file':path.name,'rect':[x0,y0,x1-x0,y1-y0],'pivot':[pivot,bottom],'hair_top':hair,'body_height':bottom-hair,'used':[int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1]})
        # One scale throughout a directional clip keeps jumps and crouches physical.
        ref=body[0] if 'states' in path.name else float(np.median(body))
        for rec in frames[row*6:row*6+6]:rec['scale']=210/ref
    for index,(other,from_index) in overrides.items():frames[index]['reuse']=[other,from_index]
    manifest[name]=frames
    print(path.name, 'body', [round(frames[r*6]['body_height']) for r in range(4)])
(base/'regions.json').write_text(json.dumps(manifest,indent=2)+'\n')
