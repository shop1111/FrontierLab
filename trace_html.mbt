///|
/// Render a trace as a self-contained offline HTML player.
pub fn render_trace_html(trace : AlgorithmTrace) -> String {
  let safe_json = trace.to_json_string().replace_all(old="<", new="\\u003c")
  let out = StringBuilder()
  let document_head =
    #|<!doctype html>
    #|<html lang="en"><head><meta charset="utf-8">
    #|<meta name="viewport" content="width=device-width,initial-scale=1">
    #|<title>FrontierLab Trace Player</title>
    #|<style>
    #|:root{color-scheme:light dark;--bg:#f8fafc;--panel:#fff;--ink:#0f172a;--muted:#64748b;--line:#cbd5e1;--accent:#2563eb}
    #|@media(prefers-color-scheme:dark){:root{--bg:#07111f;--panel:#0f172a;--ink:#f8fafc;--muted:#94a3b8;--line:#334155;--accent:#60a5fa}}
    #|*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 ui-sans-serif,system-ui,sans-serif}
    #|main{max-width:1100px;margin:auto;padding:24px}.head{display:flex;justify-content:space-between;gap:20px;align-items:end}.head h1{margin:0;font-size:clamp(25px,5vw,44px)}
    #|.muted{color:var(--muted)}.panel{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:18px;margin-top:18px;box-shadow:0 12px 30px #0001}
    #|.controls{display:grid;grid-template-columns:auto auto auto 1fr auto;gap:10px;align-items:center}button,select{border:1px solid var(--line);background:var(--panel);color:var(--ink);border-radius:9px;padding:8px 12px;font:inherit;cursor:pointer}button:hover{border-color:var(--accent)}
    #|input[type=range]{width:100%;accent-color:var(--accent)}#stage{min-height:250px;display:grid;gap:20px}.object h3{margin:0 0 10px}.sequence{display:flex;gap:10px;flex-wrap:wrap}.item,.group,.node,.cell{border:2px solid var(--line);background:color-mix(in srgb,var(--panel) 85%,#fff);border-radius:10px;transition:.18s transform,.18s background}.item{min-width:58px;text-align:center;padding:11px}.item small{display:block;color:var(--muted)}
    #|.groups{display:grid;gap:8px}.group{padding:9px 12px}.graph-svg{width:100%;min-height:260px}.grid{display:grid;gap:3px;width:max-content}.cell{width:42px;height:42px;display:grid;place-items:center;border-width:1px}.blocked{background:#1e293b;color:white}
    #|[data-role=current]{background:#f59e0b;color:#f59e0b}[data-role=candidate]{background:#38bdf8;color:#38bdf8}[data-role=compared]{background:#c084fc;color:#c084fc}[data-role=changed]{background:#fb7185;color:#fb7185}[data-role=visited]{background:#93c5fd;color:#93c5fd}[data-role=frontier]{background:#22d3ee;color:#22d3ee}[data-role=result]{background:#4ade80;color:#4ade80}[data-role=error]{background:#ef4444;color:#ef4444}
    #|.details{display:grid;grid-template-columns:2fr 1fr;gap:18px}.event{font:600 15px ui-monospace,monospace}.stats{display:flex;gap:8px;flex-wrap:wrap}.badge{border:1px solid var(--line);border-radius:99px;padding:4px 9px;color:var(--muted)}
    #|@media(max-width:700px){.controls{grid-template-columns:repeat(3,auto)}.controls input{grid-column:1/-1}.details{grid-template-columns:1fr}.head{display:block}}
    #|@media(prefers-reduced-motion:reduce){*{transition:none!important;scroll-behavior:auto!important}}
    #|</style></head><body><main>
    #|<div class="head"><div><div class="muted">MoonBit Algorithm Trace &amp; Visualization Kit</div><h1 id="title"></h1><div id="description" class="muted"></div></div><strong id="algorithm"></strong></div>
    #|<section class="panel controls" aria-label="Playback controls"><button id="prev" title="Previous (←)">← Prev</button><button id="play" title="Play or pause (Space)">Play</button><button id="next" title="Next (→)">Next →</button><input id="timeline" type="range" min="0" value="0"><select id="speed" aria-label="Playback speed"><option value="1200">0.5×</option><option value="650" selected>1×</option><option value="300">2×</option></select><output id="counter"></output></section>
    #|<section id="stage" class="panel" aria-live="polite"></section>
    #|<section class="panel details"><div><div id="event" class="event"></div><h2 id="noteTitle"></h2><p id="noteBody"></p><div id="pseudo" class="muted"></div></div><div><strong>Event statistics</strong><div id="stats" class="stats"></div></div></section>
    #|<script id="trace-data" type="application/json">
  out.write_string(document_head)
  out.write_string(safe_json)
  let document_tail =
    #|</script><script>
    #|(()=>{'use strict';const data=JSON.parse(document.getElementById('trace-data').textContent);const $=id=>document.getElementById(id);let index=-1,timer=null;
    #|$('title').textContent=data.metadata.title;$('algorithm').textContent=data.metadata.algorithm;$('description').textContent=data.metadata.description||'';$('timeline').max=Math.max(0,data.steps.length);$('timeline').value=0;
    #|const refKey=r=>`${r.object_id}::${r.entity_id||''}`;const roleMap=s=>Object.fromEntries((s.highlights||[]).map(h=>[refKey(h.target),h.role]));
    #|const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n};
    #|const ns='http://www.w3.org/2000/svg';const se=(tag,attrs,text)=>{const n=document.createElementNS(ns,tag);for(const[k,v]of Object.entries(attrs))n.setAttribute(k,v);if(text!==undefined)n.textContent=text;return n};
    #|function graphLayout(v){const n=v.nodes.length,idx=Object.fromEntries(v.nodes.map((x,i)=>[x.id,i])),deg=Array(n).fill(0),lev=Array(n).fill(0);for(const e of v.edges)if(e.from!==e.to)deg[idx[e.to]]++;const q=[];deg.forEach((d,i)=>{if(!d)q.push(i)});for(let h=0;h<q.length;h++){const c=q[h];for(const e of v.edges)if(e.from===v.nodes[c].id&&e.from!==e.to){const z=idx[e.to];lev[z]=Math.max(lev[z],lev[c]+1);if(--deg[z]===0)q.push(z)}}if(q.length===n){const slots={};return v.nodes.map((x,i)=>{const s=slots[lev[i]]||0;slots[lev[i]]=s+1;return{id:x.id,x:75+lev[i]*170,y:70+s*82}})}const off=[[0,-80],[70,-55],[90,0],[70,55],[0,80],[-70,55],[-90,0],[-70,-55]];return v.nodes.map((x,i)=>({id:x.id,x:180+Math.floor(i/8)*230+off[i%8][0],y:130+off[i%8][1]}))}
    #|function renderGraph(v,roles){const svg=se('svg',{class:'graph-svg',viewBox:'0 0 900 300',role:'img'}),pts=graphLayout(v),point=id=>pts.find(p=>p.id===id);const defs=se('defs',{}),marker=se('marker',{id:'arrow',markerWidth:8,markerHeight:8,refX:7,refY:4,orient:'auto'});marker.append(se('path',{d:'M0,0 L8,4 L0,8 z',fill:'#64748b'}));defs.append(marker);svg.append(defs);for(const e of v.edges){const a=point(e.from),b=point(e.to),attrs={fill:'none',stroke:'#64748b','stroke-width':3};if(e.directed)attrs['marker-end']='url(#arrow)';svg.append(e.from===e.to?se('path',{...attrs,d:`M ${a.x-18} ${a.y-18} C ${a.x-52} ${a.y-70}, ${a.x+52} ${a.y-70}, ${a.x+18} ${a.y-18}`}):se('line',{...attrs,x1:a.x,y1:a.y,x2:b.x,y2:b.y}));if(e.label)svg.append(se('text',{x:(a.x+b.x)/2,y:(a.y+b.y)/2-10,fill:'#94a3b8','text-anchor':'middle'},e.label))}for(const x of v.nodes){const p=point(x.id),role=roles[`${v.id}::${x.id}`]||'',g=se('g',{'data-role':role});g.append(se('circle',{cx:p.x,cy:p.y,r:27,fill:'currentColor',stroke:'#94a3b8'}));g.append(se('text',{x:p.x,y:p.y+5,'text-anchor':'middle',fill:'#0f172a'},x.label));svg.append(g)}return svg}
    #|function renderObject(v,roles){const kind=v.type,wrap=el('div','object'),title=el('h3','',v.label||v.id);wrap.append(title);
    #|if(kind==='sequence'){const row=el('div','sequence');for(const x of v.items){const n=el('div','item',x.value);n.dataset.role=roles[`${v.id}::${x.id}`]||'';n.append(el('small','',x.id));row.append(n)}wrap.append(row)}
    #|else if(kind==='sets'){const rows=el('div','groups');for(const g of v.groups){const n=el('div','group',`${g.label}: ${g.members.join(', ')}`);n.dataset.role=roles[`${v.id}::${g.id}`]||'';rows.append(n)}wrap.append(rows)}
    #|else if(kind==='graph'){wrap.append(renderGraph(v,roles))}
    #|else if(kind==='grid'){const grid=el('div','grid');grid.style.gridTemplateColumns=`repeat(${v.width},42px)`;const cells=[...v.cells].sort((a,b)=>a.y-b.y||a.x-b.x);for(const c of cells){const n=el('div',`cell${c.blocked?' blocked':''}`,c.label||'');n.dataset.role=roles[`${v.id}::${c.id}`]||'';grid.append(n)}wrap.append(grid)}return wrap}
    #|function eventName(e){return e.type}function render(){const step=index<0?null:data.steps[index],scene=step?step.scene:data.initial_scene,roles=roleMap(scene);$('stage').replaceChildren(...scene.objects.map(o=>renderObject(o,roles)));$('event').textContent=step?`Event: ${JSON.stringify(step.event)}`:'Initial scene';const note=step&&step.annotation;$('noteTitle').textContent=note?.title||'';$('noteBody').textContent=note?.body||'';$('pseudo').textContent=note?.pseudocode_line!==undefined?`Pseudocode line ${note.pseudocode_line}`:'';$('counter').textContent=`${index+1} / ${data.steps.length}`;$('timeline').value=index+1;const counts={};for(let i=0;i<=index;i++){const n=eventName(data.steps[i].event);counts[n]=(counts[n]||0)+1}$('stats').replaceChildren(...Object.entries(counts).map(([k,v])=>el('span','badge',`${k}: ${v}`)));$('prev').disabled=index<0;$('next').disabled=index>=data.steps.length-1}
    #|function go(n){index=Math.max(-1,Math.min(data.steps.length-1,n));render()}function stop(){clearInterval(timer);timer=null;$('play').textContent='Play'}$('prev').onclick=()=>go(index-1);$('next').onclick=()=>go(index+1);$('timeline').oninput=e=>go(+e.target.value-1);$('play').onclick=()=>{if(timer){stop();return}if(index>=data.steps.length-1)go(-1);$('play').textContent='Pause';timer=setInterval(()=>{if(index>=data.steps.length-1)stop();else go(index+1)},+$('speed').value)};$('speed').onchange=()=>{if(timer){stop();$('play').click()}};addEventListener('keydown',e=>{if(e.key==='ArrowLeft')go(index-1);if(e.key==='ArrowRight')go(index+1);if(e.key===' '){e.preventDefault();$('play').click()}});render()})();
    #|</script></main></body></html>
  out.write_string(document_tail)
  out.to_string()
}
