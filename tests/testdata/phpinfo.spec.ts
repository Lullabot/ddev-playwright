import { test, expect } from '@playwright/test';

test('has title', async ({ page }) => {
  await page.goto(process.env.DDEV_PRIMARY_URL);
  await expect(page).toHaveTitle(/phpinfo/);
});
