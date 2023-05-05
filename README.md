[![tests](https://github.com/deviantintegral/ddev-playwright/actions/workflows/tests.yml/badge.svg)](https://github.com/deviantintegral/ddev-playwright/actions/workflows/tests.yml) ![project is maintained](https://img.shields.io/maintenance/yes/2024.svg)

# ddev-playwright <!-- omit in toc -->

![example in action](images/demo.webp)
_Example test validating phpinfo(), slowed significantly down for the demo._

* [What is ddev-playwright?](#what-is-ddev-playwright)
* [Getting started](#getting-started)

## What is ddev-playwright?

This repository contains an addon for integrating Playwright tests into your ddev project.

Highlights include:

* Support for both npm and yarn.
* Support for running headless tests.
* Support for running headed tests with remote access to the UI through your web browser.
* Only installs the heavy Playwright dependencies if a given local opts in to them.
* Does not require running Playwright in ddev, in case developers prefer to run on the host on locals.
* Optimizations to reduce build time, especially on locals when ddev versions are upgraded.

## Getting started

```console
ddev addon get https://github.com/deviantintegral/ddev-playwright
git add .
git add -f .ddev/config.playwright.yml
mkdir -p test/playwright
# To install with npm.
ddev exec -d /var/www/html/test/playwright npm init playwright@latest
# Or yarn.
ddev exec -d /var/www/html/test/playwright yarn create playwright
# Add ignoreHTTPSErrors: true in test/playwright/playwright.config.ts to support HTTPS in tests.
# Now, install playwright dependencies and cache them for later.
ddev install-playwright
# To run playwright's test command.
ddev playwright test
# To run with the UI.
ddev playwright test --headed
# To generate playwright code by browsing.
ddev playwright codegen
```

The following services are exposed with this addon:

| Service                 | URL                               | Notes                                                                                      |
|-------------------------|-----------------------------------|--------------------------------------------------------------------------------------------|
| KasmVNC                 | https://\<PROJECT>.ddev.site:8444 | Username is your local username. Password is `secret `.                                    |
| Playwright Test Reports | https://\<PROJECT>.ddev.site:9324 | This port is changed from the default to not conflict with running Playwright on the host. |
