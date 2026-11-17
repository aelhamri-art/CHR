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
