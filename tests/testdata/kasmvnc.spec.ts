import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { existsSync, rmSync } from 'node:fs';

// Runs in Chromium, Firefox and WebKit, with no httpCredentials configured.
// Loading the HTML alone misses failures in WebSocket auth or RFB negotiation.
test('KasmVNC connects to the desktop without credentials', async ({ page }) => {
  test.setTimeout(60_000);
  const url = new URL(process.env.DDEV_PRIMARY_URL!);
  url.port = '8444';
  url.searchParams.set('autoconnect', '1');

  const response = await page.goto(url.toString());
  expect(response?.status()).toBe(200);
  expect(response?.headers()['www-authenticate']).toBeUndefined();
  await expect(page.locator('html')).toHaveClass(/noVNC_connected/, { timeout: 30_000 });

  // A completed RFB connection must have received the desktop dimensions.
  const canvas = page.locator('#noVNC_container canvas').first();
  await expect(canvas).toBeVisible();
  await expect.poll(() => canvas.evaluate((element: HTMLCanvasElement) =>
    element.width > 0 && element.height > 0
  )).toBe(true);

  // Exercise remote keyboard input through IceWM's command bar. The marker is
  // created by the remote desktop, in the same container as this test runner.
  const marker = `/tmp/kasmvnc-input-${randomUUID()}`;
  try {
    await canvas.click({ position: { x: 10, y: 10 } });
    const desktop = await canvas.screenshot();
    await page.keyboard.press('Control+Alt+Space');
    await expect.poll(async () => (await canvas.screenshot()).equals(desktop)).toBe(false);
    await page.keyboard.type(`touch ${marker}`, { delay: 20 });
    await page.keyboard.press('Enter');
    await expect.poll(() => existsSync(marker), { timeout: 10_000 }).toBe(true);
  } finally {
    rmSync(marker, { force: true });
  }
});
