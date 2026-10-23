/* Only runs in an isolated test browser with ?selftest. Does not alter project data. */
if(new URLSearchParams(location.search).has('selftest')) (async()=>{
const results=[],check=(ok,title)=>{results.push({passed:!!ok,title});document.documentElement.dataset.testProgress=String(results.length)};
try{
state.playing=false;
check(Object.keys(data.weapons).length===3,'三种武器均可检查');
const paths=new Set();let valid=true,count=0;
for(const weapon of Object.values(data.weapons))for(const directions of Object.values(weapon.clips)){
 valid&&=directions.length===8;
 for(const c of directions){valid&&=c.duration>0&&c.samples.length===121;
  for(const s of c.samples){count++;valid&&=s.cell>0&&s.baseline===s.cell*.875&&s.row>=0&&s.column>=0&&s.used.every(Number.isFinite);paths.add(s.path);for(const p of s.layers||[])paths.add(p.path);}
 }
}
check(valid&&count===3*11*8*121,'全部 31944 个导出样本有有效方向、锚点与时间');
const assetStatus=await Promise.all([...paths].map(p=>fetch(p,{method:'HEAD'}).then(r=>r.ok)));
check(assetStatus.every(Boolean),'所有实际使用图集均可读取');
state.playing=false;$('play').click();check(state.playing,'播放按钮启动动画');$('play').click();check(!state.playing,'暂停按钮停止动画');
state.time=0;$('next').click();check(Math.abs(state.time-1/60)<1e-6&&!state.playing,'单步为 1/60 秒且保持暂停');$('previous').click();check(state.time===0,'反向单步不越过起点');
document.activeElement.blur();dispatchEvent(new KeyboardEvent('keydown',{code:'ArrowRight'}));check(Math.abs(state.time-1/60)<1e-6,'键盘右箭头单步有效');
$('weapon').value='fire';$('clip').value='chain';change();
check(new Set(clip().samples.map(s=>s.path)).size===3,'大剑基础三连来自三张独立动作图集');
check([1,2,3].every(n=>clip().samples.some(s=>s.combo===n&&s.phase==='命中')),'三段均显示来自游戏时间轴的命中窗');
$('four').checked=true;render();
check(state.layouts.length===8,'八方向同屏绘制');
check(state.layouts.every(p=>{const b=clip(data.directions.indexOf(data.directions[state.layouts.indexOf(p)])).bounds;return p.fx+b[0]*p.z>=p.x-1&&p.fx+b[2]*p.z<=p.x+p.w+1&&p.fy+b[1]*p.z>=p.y-1&&p.fy+b[3]*p.z<=p.y+p.h+1}),'整段动作的稳定取景容纳完整身体和武器');
$('four').checked=false;$('weapon').value='thunder';$('clip').value='run';$('direction').value='2';change();
check(clip().samples.every(s=>s.layers?.length===2),'长枪跑步使用上身持枪、腿部步态两层');
check(new Set(clip().samples.map(s=>JSON.stringify(s.layers[0].rect))).size===16,'侧跑沿用 16 帧腿部动作');
check(new Set(clip().samples.map(s=>JSON.stringify(s.layers[1].rect))).size===1,'持枪上身不随腿步反复送枪');
$('mark').value='rear';render();const r=stage.getBoundingClientRect(),p=state.layouts[0];stage.dispatchEvent(new MouseEvent('click',{clientX:r.left+p.fx,clientY:r.top+p.fy-100}));
check(!!state.marks[annotationKey(sample())]?.rear&&!!localStorage.getItem('forest-motion-marks'),'点击握点可保存本机标注');
$('clear').click();check(!state.marks[annotationKey(sample())],'清除此帧不会保留旧标注');
$('mark').value='';$('clip').value='jump';change();
check(clip().samples.every(s=>s.path.includes('spear-poses-v3')),'长枪跳跃不再借用跑步图集');
$('weapon').value='fire';$('clip').value='hurt';change();
check(clip().samples.every(s=>s.path.includes('greatsword-poses-v3')),'大剑受击不再借用蓄力姿势');
}catch(error){check(false,String(error.stack||error))}
const ok=results.every(r=>r.passed);document.documentElement.dataset.testResult=ok?'passed':'failed';
const report=document.createElement('pre');report.id='test-report';report.textContent=JSON.stringify({passed:ok,checks:results},null,2);document.body.append(report);
state.playing=false;render();
})();
