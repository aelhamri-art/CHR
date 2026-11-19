const {test,expect}=require('@playwright/test');
test.describe('CHR storefront first-view smoke',()=>{
 test('desktop: brand landing, navigation, catalog and no runtime crash',async({page})=>{
  const errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  await page.setViewportSize({width:1440,height:900});
  await page.goto('/storefront/',{waitUntil:'domcontentloaded'});
  await expect(page.locator('.hero h1')).toBeVisible({timeout:12000});
  await expect(page.locator('.site-header')).toBeVisible();
  // Full-page screenshots must exercise below-the-fold lazy media before capture.
  for (const selector of ['.intent-rail-image','.manifesto-photo','.editorial-photo']) {
    const image=page.locator(selector).first();
    if(await image.count()){
      await image.scrollIntoViewIfNeeded();
      await expect.poll(()=>image.evaluate(img=>img.complete&&img.naturalWidth>0),{timeout:15000}).toBe(true);
    }
  }
  await page.evaluate(()=>window.scrollTo(0,0));
  await page.screenshot({path:'artifacts/chr-desktop.png',fullPage:true,animations:'disabled'});
  await expect(page.locator('.header-nav a[href="#/catalogue"]')).toBeVisible();
  await page.locator('.header-nav a[href="#/catalogue"]').click();
  await expect(page.locator('.catalog-page h1')).toBeVisible();
  const invisible=await page.locator('[data-reveal]').evaluateAll(nodes=>nodes.filter(n=>getComputedStyle(n).opacity==='0').length);
  expect(invisible,'editorial sections must never be hidden before scroll').toBe(0);
  expect(errors).toEqual([]);
 });
 test('mobile: navigation, touch targets, no horizontal overflow and account',async({page})=>{
  const errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  await page.setViewportSize({width:390,height:844});
  await page.goto('/storefront/',{waitUntil:'domcontentloaded'});
  await expect(page.locator('.hero h1')).toBeVisible({timeout:12000});
  await expect(page.locator('.mobile-bottom')).toBeVisible();
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth-innerWidth);
  expect(overflow,'page must not horizontally overflow on mobile').toBeLessThanOrEqual(2);
  for (const selector of ['.intent-rail-image','.manifesto-photo','.editorial-photo']) {
    const image=page.locator(selector).first();
    if(await image.count()){await image.scrollIntoViewIfNeeded();await expect.poll(()=>image.evaluate(img=>img.complete&&img.naturalWidth>0),{timeout:15000}).toBe(true);}
  }
  await page.evaluate(()=>window.scrollTo(0,0));
  await page.screenshot({path:'artifacts/chr-mobile.png',fullPage:true,animations:'disabled'});
  await page.locator('.mobile-bottom a[href="#/panier"]').click();
  await expect(page.locator('.basket-page h1')).toBeVisible();
  await page.locator('.mobile-bottom a[href="#/compte"]').click();
  await expect(page.locator('.auth-form')).toBeVisible();
  expect(errors).toEqual([]);
 });
 test('compact smartphone 320px: no overflow or nested scroll containers',async({page})=>{
  await page.setViewportSize({width:320,height:680});
  await page.goto('/storefront/',{waitUntil:'domcontentloaded'});
  await expect(page.locator('.hero h1')).toBeVisible({timeout:12000});
  const checks=await page.evaluate(()=>({
   overflow:document.documentElement.scrollWidth-innerWidth,
   nested:[...document.querySelectorAll('main *')].filter(n=>{
    const css=getComputedStyle(n);
    return (css.overflowY==='auto'||css.overflowY==='scroll') && n.scrollHeight>n.clientHeight+5;
   }).map(n=>n.tagName+'.'+String(n.className||'').split(' ').join('.'))
  }));
  expect(checks.overflow).toBeLessThanOrEqual(2);
  expect(checks.nested).toEqual([]);
 });
 test('keyboard: product catalog and form labels remain usable',async({page})=>{
  await page.setViewportSize({width:1024,height:768});
  await page.goto('/storefront/#/connexion',{waitUntil:'domcontentloaded'});
  await expect(page.locator('input[type=email]')).toHaveAttribute('required','');
  await expect(page.locator('input[type=password]')).toHaveAttribute('required','');
  await page.keyboard.press('Tab');
  const focused=await page.evaluate(()=>document.activeElement?.tagName);
  expect(['A','BUTTON','INPUT']).toContain(focused);
 });
});


test('V2 hero: real photo, animated hint focus safety and working search routing',async({page})=>{
 const errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.setViewportSize({width:1440,height:900});
 await page.goto('/storefront/',{waitUntil:'domcontentloaded'});
 const image=page.locator('.hero-v2-photo');
 await expect(image).toBeVisible({timeout:14000});
 await expect(page.locator('.search-orbit')).toBeVisible();
 const input=page.locator('#hero-query');
 await input.focus();
 await input.fill('four professionnel');
 await expect(input).toHaveValue('four professionnel');
 await expect(page.locator('.search-typewriter')).toBeHidden();
 await input.press('Enter');
 await expect(page.locator('.catalog-page h1')).toBeVisible();
 await expect(page.locator('.catalog-search')).toHaveValue('four professionnel');
 expect(errors).toEqual([]);
});
test('V2 mobile hero fits 320px, search and rail have no horizontal overflow',async({page})=>{
 await page.setViewportSize({width:320,height:680});
 await page.goto('/storefront/',{waitUntil:'domcontentloaded'});
 await expect(page.locator('.hero-v2-photo')).toBeVisible({timeout:14000});
 await expect(page.locator('.search-orbit-form')).toBeVisible();
 await expect(page.locator('.intent-rail')).toBeVisible();
 const metrics=await page.evaluate(()=>({
  overflow:document.documentElement.scrollWidth - innerWidth,
  searchWidth:document.querySelector('.search-orbit-form').getBoundingClientRect().width,
  pageWidth:innerWidth
 }));
 expect(metrics.overflow).toBeLessThanOrEqual(2);
 expect(metrics.searchWidth).toBeLessThanOrEqual(metrics.pageWidth);
});

test('catalogue uses server cursor pagination: 24 then 9, without loading all records',async({page})=>{
 const calls=[];
 await page.route('**/rest/v1/rpc/chr_catalog_page',async route=>{
  const body=JSON.parse(route.request().postData()||'{}');
  calls.push(body);
  const second=!!body.p_cursor_id;
  const size=second?9:24;
  const rows=Array.from({length:size},(_,i)=>{
   const id=second?i+24:i;
   const uid='11111111-1111-4111-8111-'+String(id).padStart(12,'0');
   return {store_id:'22222222-2222-4222-8222-222222222222',
    product_id:uid,variant_id:uid,product_handle:'produit-'+id,
    title:'Équipement CHR '+String(id).padStart(5,'0'),variant_title:'Standard',
    sku:'SKU-'+id,price_minor:10000+id*100,weight_grams:500,category:'Cuisson'};
  });
  await route.fulfill({status:200,contentType:'application/json',
    body:JSON.stringify({items:rows,has_more:!second,
      next_cursor:second?null:{title:rows.at(-1).title,price:rows.at(-1).price_minor,id:rows.at(-1).variant_id}})});
 });
 await page.goto('/storefront/#/catalogue',{waitUntil:'domcontentloaded'});
 await expect(page.locator('.catalog-results .product-card')).toHaveCount(24,{timeout:12000});
 await page.locator('.catalog-pager button', {hasText:'Suivant'}).click();
 await expect(page.locator('.catalog-results .product-card')).toHaveCount(9);
 expect(calls).toHaveLength(2);
 expect(calls[0].p_limit).toBe(24);
 expect(calls[1].p_cursor_id).toBeTruthy();
 expect(calls.every(call=>call.p_limit<=48)).toBe(true);
});
