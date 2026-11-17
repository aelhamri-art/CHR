const {test,expect}=require('@playwright/test');
test.describe('CHR storefront first-view smoke',()=>{
 test('desktop: brand landing, navigation, catalog and no runtime crash',async({page})=>{
  const errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  await page.setViewportSize({width:1440,height:900});
  await page.goto('/storefront/',{waitUntil:'domcontentloaded'});
  await expect(page.locator('.hero h1')).toBeVisible({timeout:12000});
  await expect(page.locator('.site-header')).toBeVisible();
  await page.screenshot({path:'artifacts/chr-desktop.png',fullPage:true,animations:'disabled'});
  await page.locator('.hero-ctas a').first().click();
  await expect(page.locator('.catalog-page h1')).toBeVisible();
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
  await page.screenshot({path:'artifacts/chr-mobile.png',fullPage:true,animations:'disabled'});
  await page.locator('.mobile-bottom a[href="#/panier"]').click();
  await expect(page.locator('.basket-page h1')).toBeVisible();
  await page.locator('.mobile-bottom a[href="#/compte"]').click();
  await expect(page.locator('.auth-form')).toBeVisible();
  expect(errors).toEqual([]);
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
