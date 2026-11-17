const {defineConfig}=require('@playwright/test');
module.exports=defineConfig({
 testDir:'./tests',
 testMatch:'visual.spec.cjs',
 timeout:25000,
 retries:1,
 reporter:'list',
 use:{baseURL:'http://127.0.0.1:8080',browserName:'chromium',trace:'retain-on-failure',screenshot:'only-on-failure'},
 webServer:{command:'python3 -m http.server 8080 --bind 127.0.0.1 --directory ..',url:'http://127.0.0.1:8080/storefront/',reuseExistingServer:false,timeout:15000},
 outputDir:'./test-results',
});
