import { test, expect } from '@playwright/test';

test('uses the add-on tmpfs for browser profiles', () => {
  expect(process.env.TMPDIR).toMatch(/^\/tmp\/sqlite\/playwright-tmp\./);
});

test('has title', async ({ page }) => {
  await page.goto(process.env.DDEV_PRIMARY_URL);
  await expect(page).toHaveTitle(/phpinfo/);
});
