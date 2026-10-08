import { test, expect, chromium } from '@playwright/test';
import { randomUUID } from 'node:crypto';

// Runs in Chromium, Firefox and WebKit, with no httpCredentials configured.
// Loading the HTML alone misses failures in WebSocket auth or RFB negotiation.
// KasmVNC is already running (test.bats checks HTTP readiness), so connection
// setup uses the fixture's normal test and assertion timeouts.
test('KasmVNC connects to the desktop without credentials', async ({ page }) => {
  // This headed browser receives input on KasmVNC's X display. Its DOM gives
  // us a direct assertion of remote input without desktop screenshot timing.
  const desktopBrowser = await chromium.launch({ headless: false, args: ['--kiosk'] });
  try {
    const desktopPage = await desktopBrowser.newPage();
    await desktopPage.setContent(`
      <style>
        body { margin: 0 }
        textarea { width: 100vw; height: 100vh; box-sizing: border-box }
      </style>
      <textarea autofocus aria-label="Remote input"></textarea>
    `);
    await desktopPage.bringToFront();
    const input = desktopPage.getByRole('textbox');
    await input.focus();

    const url = new URL(process.env.DDEV_PRIMARY_URL!);
    url.port = '8444';
    url.searchParams.set('autoconnect', '1');

    const response = await page.goto(url.toString());
    expect(response?.status()).toBe(200);
    expect(response?.headers()['www-authenticate']).toBeUndefined();
    await expect(page.locator('html')).toHaveClass(/noVNC_connected/);

    // A completed RFB connection must have received the desktop dimensions.
    const canvas = page.locator('#noVNC_container canvas').first();
    await expect(canvas).toBeVisible();
    await expect.poll(() => canvas.evaluate((element: HTMLCanvasElement) =>
      element.width > 0 && element.height > 0
    )).toBe(true);

    // The kiosk window fills the desktop with the textarea. A remote click
    // focuses it, then KasmVNC transports the keystrokes to that window.
    await canvas.click();
    const text = `kasmvnc-${randomUUID()}`;
    await page.keyboard.type(text, { delay: 20 });
    await expect(input).toHaveValue(text);
  } finally {
    await desktopBrowser.close();
  }
});
