export const ROTATIONS = [
"Je cherche un four professionnel…","Une armoire réfrigérée…",
"Une table inox…","Un lave-vaisselle professionnel…"];
export function norm(value){
 return String(value??"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLocaleLowerCase("fr").trim();
}
export function findSuggestions(products,query,max=5){
 const q=norm(query);
 if(!q)return [];
 const distinct=new Set();
 return products.filter(p=>{
  if(!p?.variant_id||distinct.has(p.variant_id))return false;
  const corpus=[p.title,p.category,p.vendor,p.sku,p.variant_title].map(norm).join(" ");
  if(!corpus.includes(q))return false;
  distinct.add(p.variant_id);return true;
 }).sort((a,b)=>{
  const x=norm(a.title),y=norm(b.title);
  return Number(!x.startsWith(q))-Number(!y.startsWith(q));
 }).slice(0,max);
}
export function createHeroSearch({products=[],onSuggest=null,onSearch,onProduct,formatPrice}){
 const elt=(tag,props={},...children)=>{
  const n=document.createElement(tag);
  for(const [key,value] of Object.entries(props)){
   if(key==="className")n.className=value;
   else if(key==="value")n.value=value;
   else if(key==="text")n.textContent=value;
   else n.setAttribute(key,String(value));
  }
  for(const child of children.flat())if(child!=null)n.append(child instanceof Node?child:document.createTextNode(String(child)));
  return n;
 };
 const wrap=elt("div",{className:"search-orbit"});
 const form=elt("form",{className:"search-orbit-form",role:"search",autocomplete:"off"});
 const label=elt("label",{className:"sr-only",for:"hero-query"},"Rechercher un équipement CHR");
 const input=elt("input",{id:"hero-query",type:"search",autocomplete:"off",spellcheck:"false",role:"combobox","aria-autocomplete":"list","aria-controls":"hero-suggest","aria-expanded":"false","aria-label":"Rechercher un équipement CHR",maxlength:"120",placeholder:" "});
 const animation=elt("span",{className:"search-typewriter","aria-hidden":"true"});
 const stack=elt("div",{className:"search-orbit-stack"},input,animation);
 const submit=elt("button",{type:"submit",className:"search-orbit-submit"},"Rechercher ↗");
 form.append(label,elt("span",{className:"search-orbit-icon","aria-hidden":"true"},"⌕"),stack,submit);
 const results=elt("div",{id:"hero-suggest",className:"hero-suggest",role:"listbox","aria-label":"Suggestions produits"});
 results.hidden=true;
 const quick=elt("div",{className:"search-quick"},elt("span",{className:"search-quick-label"},"ESSAYEZ PAR EXEMPLE"));
 for(const prompt of ["Four mixte","Froid professionnel","Table inox"]){
  const chip=elt("button",{type:"button",className:"search-quick-chip"},prompt," ↗");
  chip.addEventListener("click",()=>onSearch(prompt));
  quick.append(chip);
 }
 wrap.append(form,results,quick);
 let matches=[],selected=-1,word=0,pos=0,direction=1,timeout=null,focused=false,disposed=false;
 let suggestionSeq=0,suggestionTimer=null,suggestionError=false;
 const reduced=window.matchMedia?.("(prefers-reduced-motion: reduce)");
 const stop=()=>{if(timeout!==null)window.clearTimeout(timeout);timeout=null;};
 const step=()=>{
  stop();
  if(disposed||focused||input.value||!input.isConnected||reduced?.matches)return;
  const phrase=ROTATIONS[word%ROTATIONS.length];
  animation.textContent=phrase.slice(0,pos);
  if(direction===1){
   if(pos<phrase.length){pos++;timeout=window.setTimeout(step,60);}
   else{direction=-1;timeout=window.setTimeout(step,1700);}
  }else{
   if(pos>0){pos--;timeout=window.setTimeout(step,28);}
   else{direction=1;word++;timeout=window.setTimeout(step,350);}
  }
 };
 function hide(){results.hidden=true;input.setAttribute("aria-expanded","false");input.removeAttribute("aria-activedescendant");selected=-1;}
 function draw(){
  results.replaceChildren();
  if(!input.value.trim()){hide();return;}
  results.hidden=false;input.setAttribute("aria-expanded","true");
  if(!matches.length){results.append(elt("p",{className:"search-no-match",role:"status"},suggestionError?"Recherche temporairement indisponible. Ouvrez le catalogue ou réessayez.":"Aucune référence correspondante. Vous pouvez lancer la recherche dans le catalogue."));return;}
  for(const [i,p] of matches.entries()){
   const b=elt("button",{type:"button",className:"search-suggest-row"+(i===selected?" selected":""),role:"option",id:"suggest-"+i,"aria-selected":String(i===selected)});
   b.append(elt("span",{className:"search-suggest-icon","aria-hidden":"true"},"C."),
    elt("span",{className:"search-suggest-copy"},elt("strong",{text:p.title}),elt("small",{text:[p.category,p.sku].filter(Boolean).join(" · ")})),
    elt("span",{className:"search-suggest-price"},formatPrice?.(p.price_minor)||""));
   b.addEventListener("pointerdown",event=>event.preventDefault());
   b.addEventListener("click",()=>{hide();onProduct(p.product_handle);});
   results.append(b);
  }
  if(selected>=0)input.setAttribute("aria-activedescendant","suggest-"+selected);
  else input.removeAttribute("aria-activedescendant");
 }
 async function updateSuggestions(query,sequence){
  try{
   const next=typeof onSuggest==="function" ? await onSuggest(query) : findSuggestions(products,query);
   if(disposed||sequence!==suggestionSeq||query!==input.value.trim())return;
   matches=Array.isArray(next)?next.slice(0,5):[];
   suggestionError=false;
   draw();
  }catch(error){
   if(disposed||sequence!==suggestionSeq)return;
   matches=[];suggestionError=true;draw();
  }
 }
 function queueSuggestions(){
  selected=-1;matches=[];suggestionError=false;
  suggestionSeq+=1;
  if(suggestionTimer!==null)window.clearTimeout(suggestionTimer);
  const query=input.value.trim(),seq=suggestionSeq;
  if(query.length<2){hide();return;}
  suggestionTimer=window.setTimeout(()=>updateSuggestions(query,seq),180);
 }
 input.addEventListener("focus",()=>{focused=true;stop();animation.textContent="";if(input.value.trim())queueSuggestions();});
 input.addEventListener("input",queueSuggestions);
 input.addEventListener("keydown",event=>{
  if(event.key==="Escape"){suggestionSeq++;hide();return;}
  if((event.key==="ArrowDown"||event.key==="ArrowUp")&&matches.length){
   event.preventDefault();selected=event.key==="ArrowDown"?(selected+1)%matches.length:(selected<=0?matches.length-1:selected-1);draw();
  }
  if(event.key==="Enter"&&selected>=0&&matches[selected]){
   event.preventDefault();const p=matches[selected];hide();onProduct(p.product_handle);
  }
 });
 input.addEventListener("blur",()=>{
  focused=false;window.setTimeout(()=>{if(!wrap.contains(document.activeElement))hide();if(!input.value){pos=0;direction=1;step();}},200);
 });
 form.addEventListener("submit",e=>{e.preventDefault();const q=input.value.trim();if(q){suggestionSeq++;hide();onSearch(q);}else input.focus();});
 document.addEventListener("pointerdown",function outside(e){
  if(!wrap.isConnected){stop();disposed=true;suggestionSeq++;if(suggestionTimer!==null)window.clearTimeout(suggestionTimer);document.removeEventListener("pointerdown",outside);return;}
  if(!wrap.contains(e.target))hide();
 });
 if(reduced?.matches)animation.textContent=ROTATIONS[0];
 else window.setTimeout(step,200);
 return wrap;
}
