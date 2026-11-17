import * as api from './api.js';
import {Cart} from './cart.js';
import {euro,number,categoryName,imageUrl,clampQuantity,debounce} from './format.js';

const root=document.getElementById('app');
const toastRoot=document.getElementById('toast-root');
const SITE_SLUG=String(globalThis.CHR_SITE?.slug||'chr');
const cart=new Cart(SITE_SLUG);
const state={settings:null,items:[],user:null,profile:null,wishes:new Set(),addresses:[],quotes:[],
 search:'',sort:'name',category:'Toutes',drawer:null,productVariant:null,loading:false};
const staticCategoryIcons={'Cuisson':'♨','Froid':'❄','Laverie':'◫','Préparation':'◈','Autres':'◌'};
const icons={
 search:'<circle cx="11" cy="11" r="7"/><path d="m16 16 5 5"/>',
 user:'<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3-7 8-7s8 3 8 7"/>',
 cart:'<path d="M3 4h2l2 12h12l3-9H6"/><circle cx="10" cy="21" r="1"/><circle cx="18" cy="21" r="1"/>',
 arrow:'<path d="M4 12h16m-7-7 7 7-7 7"/>',
 close:'<path d="M5 5 19 19M19 5 5 19"/>',
 heart:'<path d="M20.8 4.7c-2.2-2.2-5.8-2.2-8 0L12 5.5l-.8-.8c-2.2-2.2-5.8-2.2-8 0-2.2 2.2-2.2 5.7 0 7.9L12 21l8.8-8.4c2.2-2.2 2.2-5.7 0-7.9z"/>',
 plus:'<path d="M12 5v14M5 12h14"/>',
 minus:'<path d="M5 12h14"/>',
 check:'<path d="m4 12 5 5 11-11"/>',
 chevron:'<path d="m9 18 6-6-6-6"/>',
 menu:'<path d="M3 7h18M3 12h18M3 17h18"/>',
 layers:'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 10h18"/>',
 shield:'<path d="M12 2 4 5v6c0 5.5 3.3 9.1 8 11 4.7-1.9 8-5.5 8-11V5l-8-3z"/><path d="m8 12 3 3 5-6"/>',
 filter:'<path d="M4 5h16M7 12h10m-7 7h4"/>',
 truck:'<path d="M3 5h12v12H3zM15 9h4l3 4v4h-7"/><circle cx="7" cy="18" r="2"/><circle cx="18" cy="18" r="2"/>'
};
const ico=(name,size=20)=>{const s=svg('svg',{width:size,height:size,viewBox:'0 0 24 24',fill:'none',stroke:'currentColor','stroke-width':'1.7','stroke-linecap':'round','stroke-linejoin':'round', 'aria-hidden':'true'});s.innerHTML=icons[name]||icons.arrow;return s;};
function svg(tag,attrs={}){const n=document.createElementNS('http://www.w3.org/2000/svg',tag);Object.entries(attrs).forEach(([k,v])=>n.setAttribute(k,String(v)));return n;}
function el(tag,attrs={},...children){
 const n=document.createElement(tag);
 for(const [k,v] of Object.entries(attrs)){
  if(v==null||v===false)continue;
  if(k==='className')n.className=v;
  else if(k==='text')n.textContent=String(v);
  else if(k==='htmlFor')n.htmlFor=v;
  else if(k==='value')n.value=v;
  else if(k==='checked')n.checked=!!v;
  else if(k==='disabled')n.disabled=!!v;
  else if(k==='required')n.required=!!v;
  else if(k==='readOnly')n.readOnly=!!v;
  else if(k==='placeholder')n.placeholder=v;
  else if(k.startsWith('on')&&typeof v==='function')n.addEventListener(k.slice(2).toLowerCase(),v);
  else n.setAttribute(k,String(v));
 }
 for(const child of children.flat(Infinity))if(child!==null&&child!==undefined&&child!==false)n.append(child instanceof Node?child:document.createTextNode(String(child)));
 return n;
}
const $=s=>root.querySelector(s);
function notify(message,tone='neutral'){
 const node=el('div',{className:'toast '+tone,role:'status'},tone==='success'?ico('check',17):null,el('span',{},message));
 toastRoot.append(node);
 setTimeout(()=>node.remove(),4800);
}
function nav(route){const target=route.replace(/^#?/,'');if(location.hash!=='#'+target)location.hash='#'+target;else render();}
function button(label,handler,cls='btn',icon=null){
 return el('button',{type:'button',className:cls,onClick:handler},label,icon?ico(icon,18):null);
}
function link(label,hash,cls=''){return el('a',{href:'#'+hash,className:cls},label);}
function section(id,cls,...content){return el('section',{id,className:cls},...content);}
function strap(title){return el('div',{className:'eyebrow'},el('i',{className:'dot'}),title);}
function bodyCopy(text){return el('p',{className:'copy'},text);}
function field(label,control){return el('label',{className:'field'},el('span',{},label),control);}
function fallbackVisual(label,extra=''){
 return el('div',{className:'visual-fallback '+extra,role:'img','aria-label':'Aucun visuel produit validé'},
 el('div',{className:'fallback-lines'},el('span'),el('span'),el('span')),
 el('span',{className:'fallback-sigil'},'C.'),el('small',{},label||'ÉQUIPEMENT CHR'));
}
function picture(item,cls=''){
 const src=imageUrl(api.supabaseUrl(),item?.image_path);
 if(!src)return fallbackVisual(item?.category||'ÉQUIPEMENT CHR',cls);
 return el('img',{className:'cover-image '+cls,src,alt:item.image_alt||item.title||'Équipement CHR',loading:'lazy',decoding:'async'});
}
function products(){const byProduct=new Map();for(const item of state.items){if(!byProduct.has(item.product_id))byProduct.set(item.product_id,[]);byProduct.get(item.product_id).push(item);}return [...byProduct.values()];}
function categories(){return ['Toutes',...[...new Set(state.items.map(i=>categoryName(i.category)))].sort((a,b)=>a.localeCompare(b,'fr'))];}
function productGrid(items,{max=Infinity}={}){
 if(!items.length)return emptyResult('Le catalogue prend forme','Les produits apparaîtront ici après validation de leur publication.');
 return el('div',{className:'product-grid'},...items.slice(0,max).map(group=>productCard(group)));
}
function productCard(group){
 const p=group[0],src=picture(p,'card-picture');
 const art=el('div',{className:'product-art'},src,
 link(el('span',{className:'sr-only'},'Voir '+p.title),'/produit/'+encodeURIComponent(p.product_handle),'product-cover-link'),
 el('div',{className:'photo-corner'},p.category||'ÉQUIPEMENT'));
 const fav=button('',async(event)=>{event.stopPropagation();await toggleWish(p.variant_id);},'favorite-btn'+(state.wishes.has(p.variant_id)?' selected':''),'heart');
 fav.setAttribute('aria-label',state.wishes.has(p.variant_id)?'Retirer des favoris':'Ajouter aux favoris');
 art.append(fav);
 const price=Math.min(...group.map(x=>x.price_minor));
 return el('article',{className:'product-card'},art,
 el('div',{className:'product-meta'},el('span',{},p.vendor||'CHR'),el('span',{},group.length>1?group.length+' variantes':'Réf. '+(p.sku||'—'))),
 link(p.title,'/produit/'+encodeURIComponent(p.product_handle),'product-name'),
 el('div',{className:'product-bottom'},
 el('div',{},el('span',{className:'price-label'},'À partir de'),el('strong',{className:'price'},euro(price)+' HT')),
 button('Découvrir',()=>nav('/produit/'+encodeURIComponent(p.product_handle)),'mini-action','arrow')));
}
function emptyResult(title,description){return el('div',{className:'empty-results'},el('span',{className:'empty-symbol'},'◌'),el('h3',{},title),bodyCopy(description));}
function header(){
 const head=el('header',{className:'site-header',id:'site-header'},
 el('div',{className:'header-inner'},
 link(el('span',{className:'logo-emblem'},'C.'),'/','logo'),
 el('nav',{className:'header-nav','aria-label':'Navigation principale'},
 link('Équipements','/catalogue'),link('Notre approche','/approche'),link('Projet professionnel','/projet')),
 el('div',{className:'header-tools'},
 button('',()=>nav('/catalogue'),'icon-button search-trigger','search'),
 button('',()=>nav('/compte'),'icon-button account-trigger','user'),
 el('button',{type:'button',className:'icon-button cart-trigger',onClick:()=>nav('/panier'),'aria-label':'Ouvrir le panier'},
 ico('cart'),el('span',{className:'cart-count'},cart.count())),
 button('',toggleMobile,'icon-button mobile-toggle','menu'))));
 return head;
}
function toggleMobile(){
 const existing=document.querySelector('.mobile-menu');
 if(existing){existing.remove();return;}
 const pane=el('div',{className:'mobile-menu'},link('Accueil','/'),link('Équipements','/catalogue'),link('Notre approche','/approche'),link('Votre projet','/projet'),link('Mon espace','/compte'));
 root.append(pane);pane.querySelectorAll('a').forEach(a=>a.addEventListener('click',()=>pane.remove()));
}
function bottomNav(){
 return el('nav',{className:'mobile-bottom','aria-label':'Navigation mobile'},
 ...[['⌂','Accueil','/'],['⌕','Recherche','/catalogue'],['▧','Panier','/panier'],['♙','Compte','/compte']]
 .map(([icon,title,to])=>el('a',{href:'#'+to,className:route().startsWith(to)&&to!=='/'?'current':''},el('span',{},icon),el('small',{},title))));
}
function footer(){
 return el('footer',{className:'footer'},
 el('div',{className:'footer-main'},
 el('div',{className:'footer-brand'},el('span',{className:'footer-monogram'},'C.'),
 el('p',{},'L’exigence professionnelle, jusque dans les détails.'),el('small',{},'Plateforme numérique CHR — catalogue vérifié avant publication.')),
 el('div',{},el('h3',{},'Explorer'),link('Équipements','/catalogue'),link('Projet professionnel','/projet'),link('Notre approche','/approche')),
 el('div',{},el('h3',{},'Votre espace'),link('Mon compte','/compte'),link('Panier','/panier'),link('Demandes de devis','/compte')),
 el('div',{},el('h3',{},'Informations'),link('Contact','/contact'),link('Confidentialité','/confidentialite'),link('Conditions','/conditions'))),
 el('div',{className:'footer-bottom'},el('span',{},'© '+new Date().getFullYear()+' CHR.'),
 el('span',{},'CONÇU POUR DURER · PENSÉ POUR AGIR')));
}
function shell(content){
 const shellNode=el('div',{className:'site-shell'},header(),el('main',{id:'main',tabIndex:-1},content),footer(),bottomNav());
 root.replaceChildren(shellNode);
 requestAnimationFrame(()=>{document.querySelectorAll('[data-reveal]').forEach(node=>observer?.observe(node));});
 document.title='CHR — '+(route()==='/'?'Équipements pour professionnels':route().split('/').filter(Boolean).pop()?.replaceAll('-',' ')||'Boutique');
}
let observer=null;
if(typeof IntersectionObserver!=='undefined'&&!matchMedia('(prefers-reduced-motion: reduce)').matches){
 observer=new IntersectionObserver(entries=>{for(const entry of entries){if(entry.isIntersecting){entry.target.classList.add('revealed');observer.unobserve(entry.target);}}},{rootMargin:'0px 0px -35px 0px',threshold:0.08});
}
function hero(){
 const setting=state.settings;
 const heroImg=setting?.hero_image_path?imageUrl(api.supabaseUrl(),setting.hero_image_path):null;
 const visual=el('div',{className:'hero-visual'},
 heroImg?el('img',{src:heroImg,className:'hero-photo',alt:'Univers de la restauration professionnelle',fetchpriority:'high'}):
 el('div',{className:'hero-architecture',role:'img','aria-label':'Composition graphique architecturale'},
 el('div',{className:'architectural-grid'}),
 el('div',{className:'steel-column first'}),el('div',{className:'steel-column second'}),el('div',{className:'steel-column third'}),
 el('div',{className:'architecture-caption'},'FORME · FONCTION · EXIGENCE')),
 el('div',{className:'hero-stamp'},'C.',el('span',{},'PROFESSIONAL EDITION')));
 return section('hero','hero',
 el('div',{className:'hero-content'},
 strap(setting?.eyebrow||'L’ESSENTIEL DES CUISINES PROFESSIONNELLES'),
 el('h1',{},setting?.headline||'La précision au service de vos ambitions.'),
 el('p',{className:'hero-lead'},setting?.subline||'Des équipements choisis avec exigence. Une expérience pensée pour vous aider à décider plus vite et plus justement.'),
 el('div',{className:'hero-ctas'},link(el('span',{},'Explorer les équipements'),ico('arrow',20),'/catalogue','btn-primary'),link('Parler de votre projet','/projet','btn-outline')),
 el('div',{className:'hero-index'},el('span',{},'01 / UNE AUTRE FAÇON DE S’ÉQUIPER.'),el('span',{},'SCROLL TO EXPLORE ↓'))),
 visual);
}
function intentSection(){
 const cats=categories().filter(c=>c!=='Toutes');
 return section('explore','section-spacing',
 el('div',{className:'section-top', 'data-reveal':''},strap('UNIVERS CHR'),el('div',{className:'section-headrow'},
 el('h2',{},'Chaque métier.',el('em',{},' Ses exigences.')),link(el('span',{},'Tout le catalogue'),ico('arrow',17),'/catalogue','text-arrow'))),
 cats.length?el('div',{className:'category-grid'},...cats.slice(0,4).map((cat,i)=>el('a',{
 href:'#/catalogue?categorie='+encodeURIComponent(cat),className:'category-tile category-'+(i%4),'data-reveal':''},
 el('span',{className:'category-index'},String(i+1).padStart(2,'0')),
 el('div',{className:'category-art'},el('span',{},staticCategoryIcons[cat]||'◇')),
 el('div',{className:'category-title'},cat,ico('arrow',20))))):el('div',{className:'category-placeholder'},
 el('span',{className:'category-placeholder-symbol'},'C / 01'),
 el('div',{},el('h3',{},'Une sélection qui se construit avec précision.'),bodyCopy('Les univers et les produits seront visibles dès que leur catalogue et leurs visuels auront été validés.')),
 link('Découvrir notre approche','/approche','text-arrow')));
}
function manifesto(){
 return section('philosophie','manifesto-section',
 el('div',{className:'manifesto-index'},'NOTRE CONVICTION / 001'),
 el('blockquote',{className:'manifesto-quote','data-reveal':''},
 'Le bon équipement ne se contente pas d’occuper une cuisine. Il donne à chaque geste sa pleine mesure.'),
 el('div',{className:'manifesto-foot'},strap('L’EXIGENCE SANS LE SUPERFLU'),link('Découvrir notre approche','/approche','text-arrow')));
}
function bestsellers(){
 const groups=products();
 return section('selection','section-spacing selection-section',
 el('div',{className:'section-top','data-reveal':''},strap('LE CATALOGUE'),el('div',{className:'section-headrow'},
 el('h2',{},'À découvrir.',el('em',{},' Pour vos projets.')),link('Explorer tous les équipements','/catalogue','text-arrow'))),
 productGrid(groups,{max:4}));
}
function serviceSection(){
 return section('services','editorial-block',
 el('div',{className:'editorial-art','data-reveal':''},
 el('div',{className:'editorial-object'},el('div'),el('span',{},'UNE VISION PLUS CLAIRE')),
 el('div',{className:'editorial-vertical'},'PENSÉ POUR VOTRE MÉTIER')),
 el('div',{className:'editorial-copy','data-reveal':''},
 strap('VOTRE PROJET AVANT TOUT'),el('h2',{},'Plus qu’une référence.',el('em',{},' Une bonne décision.')),
 bodyCopy('Un achat professionnel engage votre activité. Comparez les caractéristiques utiles, sélectionnez vos références et préparez votre demande dans un espace unique.'),
 link(el('span',{},'Préparer mon projet'),ico('arrow',19),'/projet','btn-dark')));
}
function servicePoints(){
 const content=[['01','CLARTÉ','Des fiches structurées pour comparer les informations réellement disponibles.'],
 ['02','MAÎTRISE','Un panier qui conserve vos références entre deux visites sur votre appareil.'],
 ['03','CONTINUITÉ','Un espace personnel pour retrouver vos demandes et coordonnées.']];
 return section('principes','principles',
 el('div',{className:'principles-head'},strap('L’EXPÉRIENCE CHR'),el('h2',{},'La simplicité.',el('em',{},' Sans compromis.'))),
 el('div',{className:'principles-grid'},...content.map(([id,title,description])=>
 el('div',{className:'principle','data-reveal':''},el('span',{},id),el('h3',{},title),bodyCopy(description)))));
}
function closeSection(){
 return section('last-cta','last-cta',el('div',{className:'last-pattern'}),
 el('div',{className:'last-content'},strap('DÉMARREZ AVEC UNE IDÉE CLAIRE'),
 el('h2',{},'Les grands projets.',el('em',{},' Commencent ici.')),
 bodyCopy('Composez votre sélection à votre rythme, puis transformez-la en demande de devis.'),
 link(el('span',{},'Construire mon projet'),ico('arrow',20),'/catalogue','btn-lime')));
}
function home(){
 return el('div',{},!state.settings?el('div',{className:'status-banner',role:'status'},'Présentation en préparation · Catalogue non publié'):null,
 hero(),intentSection(),manifesto(),bestsellers(),serviceSection(),servicePoints(),closeSection());
}
function catalogPage(){
 const params=new URLSearchParams(route().split('?')[1]||'');
 if(params.has('categorie'))state.category=params.get('categorie');
 const filtered=()=> {
  const q=state.search.trim().normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  const group=products().filter(g=>{
   const p=g[0],hay=(p.title+' '+(p.vendor||'')+' '+(p.category||'')+' '+g.map(v=>v.sku+' '+v.variant_title).join(' ')).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
   return (state.category==='Toutes'||categoryName(p.category)===state.category)&&(!q||hay.includes(q));
  });
  if(state.sort==='price-low')group.sort((a,b)=>Math.min(...a.map(p=>p.price_minor))-Math.min(...b.map(p=>p.price_minor)));
  if(state.sort==='price-high')group.sort((a,b)=>Math.min(...b.map(p=>p.price_minor))-Math.min(...a.map(p=>p.price_minor)));
  if(state.sort==='name')group.sort((a,b)=>a[0].title.localeCompare(b[0].title,'fr'));
  return group;
 };
 const search=el('input',{type:'search',className:'catalog-search',placeholder:'Un équipement, une référence, un fabricant…',
 'aria-label':'Rechercher un équipement',value:state.search,autocomplete:'off'});
 const categoriesRow=el('div',{className:'filter-pills'});
 const results=el('div',{className:'catalog-results'});
 const count=el('span',{className:'catalog-count'});
 const sort=el('select',{className:'sort-select','aria-label':'Trier les produits'},
 ...[['name','Nom A → Z'],['price-low','Prix croissant'],['price-high','Prix décroissant']]
 .map(([value,label])=>el('option',{value,selected:value===state.sort},label)));
 function apply(){
  const groups=filtered();
  count.textContent=groups.length+' produit'+(groups.length>1?'s':'');
  results.replaceChildren(productGrid(groups));
  categoriesRow.replaceChildren(...categories().map(cat=>button(cat,()=>{
   state.category=cat;apply();
  },'filter-pill'+(cat===state.category?' active':''))));
 }
 search.addEventListener('input',debounce(e=>{state.search=e.target.value;apply();},100));
 sort.addEventListener('change',()=>{state.sort=sort.value;apply();});
 const page=el('div',{className:'catalog-page page-container'},
 el('div',{className:'catalog-intro'},strap('CATALOGUE PROFESSIONNEL'),el('h1',{},'Les outils de votre excellence.'),bodyCopy('Parcourez les équipements publiés et composez votre sélection.')),
 el('div',{className:'catalog-controls'},el('div',{className:'search-wrap'},ico('search'),search),
 el('div',{className:'sort-wrap'},count,sort)),
 categoriesRow,results);
 apply();return page;
}
function productPage(handle){
 const group=products().find(g=>g[0].product_handle===decodeURIComponent(handle||''));
 if(!group)return el('div',{className:'page-container error-page'},strap('RÉFÉRENCE INTROUVABLE'),
 el('h1',{},'Ce produit n’est pas disponible.'),bodyCopy('Il a peut-être été retiré du catalogue.'),link('Retour au catalogue','/catalogue','btn-dark'));
 const p=group[0];
 if(!group.some(item=>item.variant_id===state.productVariant))state.productVariant=p.variant_id;
 const selected=state.productVariant&&group.find(x=>x.variant_id===state.productVariant)||p;
 const media=el('div',{className:'detail-picture'},picture(p,'detail-image'),
 el('span',{className:'detail-photo-label'},p.category||'ÉQUIPEMENT PROFESSIONNEL'));
 const price=el('strong',{className:'detail-price'},euro(selected.price_minor)+' HT');
 const ref=el('span',{className:'detail-ref'},'Référence : '+(selected.sku||'—'));
 const selector=el('div',{className:'variant-options'});
 const quantity=el('input',{type:'number',min:1,max:999,step:1,value:1,'aria-label':'Quantité'});
 function choose(v){
  state.productVariant=v.variant_id;
  price.textContent=euro(v.price_minor)+' HT';
  ref.textContent='Référence : '+(v.sku||'—');
  selector.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.variant===v.variant_id)));
 }
 for(const variant of group){
  const b=button(variant.variant_title,()=>choose(variant),'variant-pill');
  b.dataset.variant=variant.variant_id;
  b.setAttribute('aria-pressed',String(variant.variant_id===selected.variant_id));
  selector.append(b);
 }
 const add=button('Ajouter à ma sélection',()=>{
  try{const q=clampQuantity(quantity.value);cart.add(state.productVariant||selected.variant_id,q);notify('Ajouté à votre sélection','success');refreshCounts();}
  catch(e){notify(e.message,'error');}
 },'btn-dark full-width','plus');
 const fav=button('Ajouter aux favoris',async()=>toggleWish(state.productVariant||selected.variant_id),'btn-outline dark-outline','heart');
 const desc=(p.description||'').trim();
 const info=el('div',{className:'product-info'},strap('MATÉRIEL CHR'),
 el('h1',{},p.title),ref,
 el('div',{className:'detail-price-wrap'},price,el('span',{},'Prix affiché hors taxes ; livraison et taxes finales à confirmer.')),
 el('div',{className:'detail-separator'}),
 el('h3',{},'Choisissez votre version'),selector,
 el('div',{className:'buy-area'},el('label',{className:'qty-field'},'Quantité',quantity),add),
 fav,
 el('div',{className:'detail-separator'}),
 el('div',{className:'product-specs'},strap('À SAVOIR'),
 ...[['Fabricant',p.vendor||'Non renseigné'],['Poids',selected.weight_grams?number(selected.weight_grams)+' g':'Non renseigné'],
 ['SKU',selected.sku||'Non renseigné'],['Variante',selected.variant_title]].map(([k,v])=>el('div',{},el('span',{},k),el('strong',{},v)))));
 return el('div',{className:'product-page page-container'},
 el('nav',{className:'breadcrumbs','aria-label':'Fil d’Ariane'},link('Accueil','/'),' / ',link('Catalogue','/catalogue'),' / ',p.title),
 el('div',{className:'detail-grid'},media,info),
 el('div',{className:'description-section'},strap('CARACTÉRISTIQUES'),el('h2',{},'Ce qu’il faut savoir.'),bodyCopy(desc||'Description technique en préparation : contactez CHR pour obtenir les informations détaillées.')),
 section('product-cta','detail-cta',el('h2',{},'Une question sur cette référence ?'),bodyCopy('Ajoutez-la à votre sélection et préparez votre demande professionnelle.'),link('Voir mon projet','/panier','btn-dark')));
}
function cartPage(){
 const lines=cart.lines(state.items);
 const items=el('div',{className:'cart-items'});
 const subtotal=el('strong',{className:'basket-total'},euro(cart.subtotal(state.items))+' HT');
 const totalNote=el('p',{className:'muted'},'Estimation hors taxes, hors livraison. Prix et disponibilités confirmés lors du traitement de la demande.');
 function update(){
  items.replaceChildren(...cart.lines(state.items).map(({product:p,variant_id,quantity:q})=>{
   const inc=button('+',()=>{cart.set(variant_id,Math.min(999,q+1));update();},'stepper-btn');
   const dec=button('−',()=>{cart.set(variant_id,q-1);update();},'stepper-btn');
   return el('div',{className:'cart-line'},picture(p,'cart-image'),
   el('div',{},el('h3',{},p.title),el('small',{},p.variant_title),el('strong',{},euro(p.price_minor)+' HT'),
   el('div',{className:'cart-controls'},el('div',{className:'stepper'},dec,el('span',{},String(q)),inc),
   button('Retirer',()=>{cart.remove(variant_id);update();},'text-link'))));
  }));
  if(!cart.count()||!items.children.length)items.append(emptyResult('Votre sélection est vide','Explorez le catalogue pour composer votre projet.'));
  subtotal.textContent=euro(cart.subtotal(state.items))+' HT';refreshCounts();
 }
 const requestBtn=button('Demander un devis',()=>nav('/devis'),'btn-dark full-width','arrow');
 const summary=el('aside',{className:'basket-summary'},strap('VOTRE SÉLECTION'),el('h2',{},'Le récapitulatif'),
 el('div',{className:'subtotal-row'},'Sous-total des références',subtotal),totalNote,
 requestBtn,el('p',{className:'payment-notice'},'Le règlement en ligne sera proposé après activation et validation du prestataire de paiement.'));
 const page=el('div',{className:'page-container basket-page'},
 strap('PROJET PROFESSIONNEL'),el('h1',{},'Votre sélection.'),bodyCopy('Regroupez vos équipements, ajustez vos quantités et demandez un devis.'),
 el('div',{className:'basket-grid'},items,summary));
 update();return page;
}
function quotePage(){
 const lines=cart.lines(state.items);
 if(!lines.length)return el('div',{className:'page-container empty-page'},emptyResult('Pas encore de sélection','Ajoutez des produits au panier avant de demander un devis.'),link('Explorer le catalogue','/catalogue','btn-dark'));
 if(!state.settings?.store_id)return el('div',{className:'page-container'},emptyResult('Demandes non ouvertes','La boutique CHR est encore en préparation.'));
 if(!state.user)return el('div',{className:'page-container narrow'},strap('DEMANDE PROFESSIONNELLE'),el('h1',{},'Connectez-vous pour poursuivre.'),bodyCopy('Un compte permet de suivre votre demande sans perdre votre sélection.'),link('Créer mon accès','/connexion','btn-dark'));
 const company=el('input',{name:'company',value:state.profile?.company_name||'',placeholder:'Votre établissement'});
 const email=el('input',{type:'email',name:'email',value:state.user.email||'',required:true});
 const note=el('textarea',{name:'notes',rows:5,placeholder:'Parlez-nous de vos besoins, contraintes ou délais éventuels.'});
 const submit=el('button',{className:'btn-dark full-width',type:'submit'},'Envoyer ma demande',ico('arrow',19));
 let key=crypto.randomUUID();
 const form=el('form',{className:'quote-form',onSubmit:async e=>{
  e.preventDefault();submit.disabled=true;
  try{
   if(!state.profile)state.profile=await api.saveProfile(state.settings.store_id,state.user.id,{company_name:company.value.trim()});
   const result=await api.requestQuote(state.settings.store_id,lines,company.value.trim(),email.value.trim(),note.value.trim(),key);
   notify('Demande enregistrée. Vous la retrouverez dans votre espace.','success');cart.clear();await loadPersonal();nav('/compte');
  }catch(error){notify(error.message,'error');}
  finally{submit.disabled=false;}
 }},field('Entreprise / établissement',company),field('Adresse e-mail',email),field('Votre besoin (facultatif)',note),
 el('p',{className:'muted'},'Aucun paiement n’est réalisé. Le devis est une demande et ne vaut pas confirmation de commande.'),submit);
 return el('div',{className:'page-container quote-page'},strap('DERNIÈRE ÉTAPE'),el('h1',{},'Votre projet prend forme.'),bodyCopy('Précisez vos besoins pour transmettre votre demande à CHR.'),
 el('div',{className:'quote-grid'},el('div',{className:'quote-content'},form),
 el('aside',{className:'quote-summary'},el('h2',{},'Votre sélection'),...lines.map(x=>el('div',{className:'quote-item'},el('span',{},x.product.title+' × '+x.quantity),el('strong',{},euro(x.product.price_minor*x.quantity)))),
 el('div',{className:'quote-total'},'Estimation HT',el('strong',{},euro(cart.subtotal(state.items)))))));
}
function projectPage(){
 return el('div',{},section('project-hero','project-hero',
 strap('POUR LES PROJETS QUI COMPTENT'),
 el('h1',{},'Chaque détail.',el('em',{},' Compte.')),
 bodyCopy('Listez vos besoins, explorez les références et préparez une demande qui respecte les réalités de votre métier.'),
 link(el('span',{},'Composer ma sélection'),ico('arrow',20),'/catalogue','btn-primary')),
 servicePoints(),
 section('project-method','section-spacing page-container',
 el('div',{className:'section-top'},strap('VOTRE MÉTHODE'),el('h2',{},'Du besoin.',el('em',{},' À la décision.'))),
 el('div',{className:'steps-grid'},...[
 ['01','Explorez','Identifiez les références adaptées dans le catalogue.'],
 ['02','Sélectionnez','Regroupez vos produits et vos quantités dans le panier.'],
 ['03','Demandez','Transmettez votre besoin professionnel pour recevoir un suivi.']
 ].map(([num,title,copy])=>el('div',{className:'step'},el('span',{},num),el('h3',{},title),bodyCopy(copy))))));
}
function aboutPage(){
 return el('div',{},section('about-hero','about-hero',
 strap('NOTRE APPROCHE'),el('h1',{},'Le matériel d’abord.',el('em',{},' Votre métier toujours.')),
 bodyCopy('Une expérience dédiée à la recherche, à la compréhension et à la sélection d’équipements professionnels. Des informations claires et des décisions éclairées.'),
 link('Découvrir les équipements','/catalogue','btn-primary')),manifesto(),servicePoints());
}
function contactPage(){
 const email=state.settings?.contact_email;
 return el('div',{className:'page-container information-page'},strap('RESTONS EN CONTACT'),el('h1',{},'Comment vous accompagner ?'),
 bodyCopy('Une question sur une référence, un projet d’équipement ou votre demande ?'),
 email?el('a',{className:'btn-dark',href:'mailto:'+email},'Écrire à CHR'):el('p',{className:'notice'},'Les coordonnées de contact seront affichées après validation par CHR.'),
 link('Explorer le catalogue','/catalogue','text-arrow'));
}
function legalPage(type){
 const confidentiality=type==='confidentialite';
 const approved=confidentiality?state.settings?.privacy_policy:state.settings?.terms_of_sale;
 const legal=state.settings?.legal_notice;
 return el('div',{className:'page-container information-page'},strap('INFORMATIONS'),el('h1',{},confidentiality?'Confidentialité':'Conditions de vente'),
 approved?el('div',{className:'legal-text'},...approved.split(/\n{2,}/).map(s=>el('p',{},s))):el('p',{className:'notice'},'Document légal en cours de validation par CHR. La vente en ligne n’est pas activée.'),
 legal?el('details',{},el('summary',{},'Mentions légales'),el('div',{className:'legal-text'},...legal.split(/\n{2,}/).map(s=>el('p',{},s)))):null,
 link('Retour à l’accueil','/','text-arrow'));
}
function formInput(label,name,type='text',value='',extra={}){return field(label,el('input',{name,type,value,...extra}));}
function authPage(mode='login'){
 let stateMode=mode;
 const page=el('div',{className:'auth-layout'},
 el('aside',{className:'auth-visual'},
 el('span',{className:'auth-mark'},'C.'),el('div',{},strap('BIENVENUE CHEZ CHR'),el('h2',{},'Votre projet.',el('em',{},' Votre espace.')),bodyCopy('Retrouvez vos références, vos préférences et vos demandes dans un espace conçu pour les professionnels.'))),
 el('div',{className:'auth-card'}));
 function switchMode(next){stateMode=next;renderForm();}
 function renderForm(){
  const title=stateMode==='signup'?'Créer votre espace':stateMode==='recover'?'Récupérer votre accès':'Connectez-vous.';
  const description=stateMode==='signup'?'Votre compte personnel, sans configuration compliquée.':stateMode==='recover'?'Recevez un lien de réinitialisation sur votre adresse e-mail.':'Reprenez votre projet là où vous l’avez laissé.';
  const email=el('input',{type:'email',name:'email',autocomplete:'email',required:true,placeholder:'prenom@entreprise.fr'});
  const password=stateMode==='recover'?null:el('input',{type:'password',name:'password',minlength:stateMode==='signup'?8:6,
    autocomplete:stateMode==='signup'?'new-password':'current-password',required:true,placeholder:'••••••••'});
  const submit=el('button',{className:'btn-dark full-width',type:'submit'},stateMode==='signup'?'Créer mon compte':stateMode==='recover'?'Envoyer le lien':'Se connecter',ico('arrow',18));
  const form=el('form',{className:'auth-form',onSubmit:async e=>{
   e.preventDefault();submit.disabled=true;
   try{
    if(stateMode==='signup'){await api.signup(email.value.trim(),password.value);notify('Compte demandé. Vérifiez votre boîte e-mail pour confirmer votre adresse.','success');switchMode('login');return;}
    if(stateMode==='recover'){await api.recover(email.value.trim());notify('Si ce compte existe, un lien de récupération a été envoyé.','success');switchMode('login');return;}
    await api.login(email.value.trim(),password.value);state.user=await api.user();state.settings=await api.settings(SITE_SLUG);state.items=state.settings?await api.catalog(state.settings.store_id):[];await loadPersonal();notify('Vous êtes connecté.','success');nav('/compte');
   }catch(error){notify(error.message,'error');}
   finally{submit.disabled=false;}
  }},field('Adresse e-mail',email),password?field('Mot de passe',password):null,submit);
  page.querySelector('.auth-card').replaceChildren(strap('MON ESPACE'),
   el('h1',{},title),bodyCopy(description),form,
   el('div',{className:'auth-links'},
   stateMode==='login'?button('Mot de passe oublié ?',()=>switchMode('recover'),'text-link'):null,
   stateMode==='signup'?button('Déjà un compte ? Connexion',()=>switchMode('login'),'text-link'):
   stateMode==='login'?button('Créer un compte',()=>switchMode('signup'),'text-link'):
   button('Retour à la connexion',()=>switchMode('login'),'text-link')));
 }
 renderForm();return page;
}
async function loadPersonal(){
 if(!state.user||!state.settings?.store_id){state.profile=null;state.addresses=[];state.quotes=[];state.wishes=new Set();return;}
 const id=state.settings.store_id;
 const results=await Promise.allSettled([api.profile(id),api.addresses(id),api.quotes(id),api.wishlist(id),api.savedCart(id)]);
 if(results[0].status==='fulfilled')state.profile=results[0].value;
 if(results[1].status==='fulfilled')state.addresses=results[1].value||[];
 if(results[2].status==='fulfilled')state.quotes=results[2].value||[];
 if(results[3].status==='fulfilled')state.wishes=new Set((results[3].value||[]).map(x=>x.variant_id));
 if(results[4].status==='fulfilled'){
  const stored=Object.fromEntries((results[4].value||[]).map(x=>[x.variant_id,x.quantity]));
  cart.merge(stored);
 }
}
async function toggleWish(id){
 if(!state.user)return nav('/connexion');
 if(!state.settings?.store_id)return notify('Boutique en préparation.');
 try{
  if(!state.profile){state.profile=await api.saveProfile(state.settings.store_id,state.user.id,{});}
  if(state.wishes.has(id)){await api.removeWish(state.settings.store_id,id);state.wishes.delete(id);notify('Retiré des favoris.','success');}
  else{await api.addWish(state.settings.store_id,state.user.id,id);state.wishes.add(id);notify('Ajouté aux favoris.','success');}
  render();
 }catch(error){notify(error.message,'error');}
}
async function accountPage(){
 if(!state.user)return authPage('login');
 if(!state.settings?.store_id)return el('div',{className:'page-container information-page'},strap('ESPACE EN PRÉPARATION'),el('h1',{},'Boutique non ouverte.'),bodyCopy('Votre connexion est active. Le profil commercial sera disponible à la publication de la boutique.'));
 const profile=state.profile||{};
 const first=el('input',{name:'first_name',value:profile.first_name||'',autocomplete:'given-name'});
 const last=el('input',{name:'last_name',value:profile.last_name||'',autocomplete:'family-name'});
 const company=el('input',{name:'company_name',value:profile.company_name||'',autocomplete:'organization'});
 const phone=el('input',{name:'phone',value:profile.phone||'',autocomplete:'tel'});
 const optin=el('input',{type:'checkbox',name:'marketing_opt_in',checked:!!profile.marketing_opt_in});
 const save=el('button',{type:'submit',className:'btn-dark'},'Enregistrer les modifications',ico('check',17));
 const profileForm=el('form',{className:'profile-form',onSubmit:async e=>{
  e.preventDefault();save.disabled=true;
  try{
   state.profile=await api.saveProfile(state.settings.store_id,state.user.id,{
    first_name:first.value.trim(),last_name:last.value.trim(),company_name:company.value.trim(),phone:phone.value.trim(),
    marketing_opt_in:optin.checked});
   notify('Profil enregistré.','success');
  }catch(error){notify(error.message,'error');}
  finally{save.disabled=false;}
 }},formInput('E-mail','email','email',state.user.email||'',{readOnly:true}),
 field('Prénom',first),field('Nom',last),field('Entreprise',company),field('Téléphone',phone),
 el('label',{className:'check-label'},optin,'J’accepte de recevoir des informations commerciales par e-mail.'),save);
 const addrList=el('div',{className:'address-list'});
 function fillAddresses(){
  addrList.replaceChildren(...(state.addresses.length?state.addresses.map(a=>el('div',{className:'address-card'},
    el('strong',{},a.label||'Adresse'),el('p',{},a.recipient+' · '+a.line1+', '+a.postal_code+' '+a.city),
    button('Supprimer',async()=>{
     if(!confirm('Supprimer cette adresse ?'))return;
     try{await api.deleteAddress(state.settings.store_id,a.id);state.addresses=await api.addresses(state.settings.store_id);fillAddresses();notify('Adresse supprimée.','success');}
     catch(e){notify(e.message,'error');}
    },'text-link'))):[bodyCopy('Aucune adresse enregistrée.')]));
 }
 fillAddresses();
 const addressForm=el('form',{className:'address-form',onSubmit:async e=>{
  e.preventDefault();const fd=new FormData(e.currentTarget);
  if(!state.settings?.store_id)return notify('Boutique indisponible.','error');
  try{
   if(!state.profile)state.profile=await api.saveProfile(state.settings.store_id,state.user.id,{});
   await api.addAddress(state.settings.store_id,state.user.id,{
    label:String(fd.get('label')).trim(),recipient:String(fd.get('recipient')).trim(),line1:String(fd.get('line1')).trim(),
    postal_code:String(fd.get('postal_code')).trim(),city:String(fd.get('city')).trim(),country:String(fd.get('country')).trim().toUpperCase()});
   state.addresses=await api.addresses(state.settings.store_id);fillAddresses();e.currentTarget.reset();notify('Adresse ajoutée.','success');
  }catch(error){notify(error.message,'error');}
 }},formInput('Libellé','label','text','Livraison',{required:true}),
 formInput('Destinataire','recipient','text','',{required:true}),
 formInput('Adresse','line1','text','',{required:true}),
 formInput('Code postal','postal_code','text','',{required:true}),
 formInput('Ville','city','text','',{required:true}),
 formInput('Pays ISO','country','text','FR',{required:true,maxLength:2}),
 el('button',{className:'btn-dark',type:'submit'},'Ajouter une adresse',ico('plus',17)));
 const quoteList=el('div',{className:'quotes-list'},
 ...(state.quotes.length?state.quotes.map(q=>el('div',{className:'quote-card'},
 el('span',{},new Date(q.created_at).toLocaleDateString('fr-FR')),
 el('strong',{},euro(q.estimate_minor)+' HT'),
 el('span',{className:'pill'},({new:'Reçue',reviewing:'En cours',replied:'Réponse envoyée',closed:'Clôturée'})[q.status]||q.status))):
 [bodyCopy('Aucune demande pour le moment.')]));
 const count=state.wishes.size;
 const panel=el('div',{className:'account-content'},
 el('div',{className:'account-welcome'},strap('ESPACE PROFESSIONNEL'),el('h1',{},'Bonjour,'),el('p',{},state.user.email||'')),
 el('div',{className:'account-stat-row'},
 ...[['Mes demandes',state.quotes.length],['Mes favoris',count],['Mes adresses',state.addresses.length]]
 .map(([label,value])=>el('div',{},el('strong',{},value),el('span',{},label)))),
 section('profile','account-panel',el('h2',{},'Mon profil'),profileForm),
 section('addresses','account-panel',el('h2',{},'Mes adresses'),addrList,el('h3',{},'Nouvelle adresse'),addressForm),
 section('quotes','account-panel',el('h2',{},'Demandes de devis'),quoteList),
 section('payment','account-panel',el('h2',{},'Moyens de paiement'),el('div',{className:'payment-empty'},ico('shield',27),
 el('div',{},el('strong',{},'Paiement sécurisé à venir'),bodyCopy('La mémorisation des cartes sera activée après connexion d’un prestataire agréé. Aucune donnée de carte n’est collectée ici.')))),
 el('div',{className:'logout-row'},button('Se déconnecter',async()=>{
  try{await api.logout();state.user=null;state.profile=null;state.addresses=[];state.quotes=[];state.wishes.clear();notify('Déconnexion effectuée.');nav('/');}
  catch(err){notify(err.message,'error');}
 },'btn-outline dark-outline')));
 return el('div',{className:'page-container account-page'},panel);
}
function route(){return decodeURI(location.hash.replace(/^#/,''))||'/';}
function refreshCounts(){root.querySelectorAll('.cart-count').forEach(n=>n.textContent=String(cart.count()));}
async function render(){
 const r=route();
 if(r==='/compte'&&state.user&&state.settings){try{await loadPersonal();}catch(e){notify(e.message,'error');}}
 const scroll=window.scrollY;
 let view;
 if(r==='/'||r==='/accueil')view=home();
 else if(r.startsWith('/catalogue'))view=catalogPage();
 else if(r.startsWith('/produit/'))view=productPage(r.slice('/produit/'.length).split('?')[0]);
 else if(r==='/panier')view=cartPage();
 else if(r==='/devis')view=quotePage();
 else if(r==='/projet')view=projectPage();
 else if(r==='/approche')view=aboutPage();
 else if(r==='/contact')view=contactPage();
 else if(r==='/confidentialite'||r==='/conditions')view=legalPage(r.slice(1));
 else if(r==='/connexion')view=authPage('login');
 else if(r==='/inscription')view=authPage('signup');
 else if(r==='/compte')view=await accountPage();
 else view=el('div',{className:'page-container error-page'},el('h1',{},'Cette page n’existe pas.'),link('Retour à l’accueil','/','btn-dark'));
 shell(view);refreshCounts();
 if(state.lastRoute!==r){window.scrollTo({top:0,behavior:'auto'});state.lastRoute=r;}
 else if(scroll)window.scrollTo(0,scroll);
}
function setupCartSync(){
 let debounceTimer;
 let previous={...cart.items};
 cart.subscribe(()=>{
  refreshCounts();
  clearTimeout(debounceTimer);
  const changes=Object.keys({...previous,...cart.items}).filter(id=>(previous[id]||0)!==(cart.items[id]||0));
  previous={...cart.items};
  if(!state.user||!state.profile||!state.settings?.store_id||!changes.length)return;
  debounceTimer=setTimeout(()=>{
   const storeId=state.settings.store_id;
   for(const id of changes){
    api.saveCartLine(storeId,state.user.id,id,cart.items[id]||0).catch(()=>{});
   }
  },350);
 });
}
async function boot(){
 if(!api.configured()){
  root.replaceChildren(el('main',{className:'fatal-screen'},el('h1',{},'Configuration requise'),bodyCopy('La connexion publique à Supabase CHR doit être configurée.')));
  return;
 }
 setupCartSync();
 try{
  const [settings,user]=await Promise.allSettled([api.settings(SITE_SLUG),api.user()]);
  if(settings.status==='rejected')throw settings.reason;
  state.settings=settings.value;
  state.user=user.status==='fulfilled'?user.value:null;
  state.items=state.settings?await api.catalog(state.settings.store_id):[];
  if(state.user&&state.settings)await loadPersonal();
  await render();
 }catch(e){
  root.replaceChildren(el('main',{className:'fatal-screen'},
   el('h1',{},'La boutique est momentanément indisponible.'),
   bodyCopy(e?.message||'Impossible de récupérer les données.'),
   button('Réessayer',()=>location.reload(),'btn-dark')));
 }
}
window.addEventListener('hashchange',()=>{
 document.querySelector('.mobile-menu')?.remove();
 render().catch(e=>notify(e.message,'error'));
});
boot();
