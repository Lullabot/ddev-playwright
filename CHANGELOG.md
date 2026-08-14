# Changelog

## [0.5.6](https://github.com/Lullabot/ddev-playwright/compare/v0.5.5...v0.5.6) (2026-08-14)


### Bug Fixes

* stage only dependency manifests into the browser build context ([#137](https://github.com/Lullabot/ddev-playwright/issues/137)) ([5f81503](https://github.com/Lullabot/ddev-playwright/commit/5f815033f896ee887f711ba67ff681c5516ecc3f))


### Performance Improvements

* order web image layers so test edits stop rebuilding the world ([#136](https://github.com/Lullabot/ddev-playwright/issues/136)) ([6baf3a5](https://github.com/Lullabot/ddev-playwright/commit/6baf3a5da15acee015d28c77b6c857dbac039a47))

## [0.5.5](https://github.com/Lullabot/ddev-playwright/compare/v0.5.4...v0.5.5) (2026-08-07)


### Features

* support configurable PLAYWRIGHT_TEST_DIR ([#123](https://github.com/Lullabot/ddev-playwright/issues/123)) ([3901574](https://github.com/Lullabot/ddev-playwright/commit/3901574624df3f47f953fd101eb32ec63bd71d65))


### Bug Fixes

* ddev restart failing on macOS with playwright via npm ([#127](https://github.com/Lullabot/ddev-playwright/issues/127)) ([8291562](https://github.com/Lullabot/ddev-playwright/commit/829156253e765213a34bc73d05df4e8c39e4a561))

## [0.5.4](https://github.com/Lullabot/ddev-playwright/compare/v0.5.3...v0.5.4) (2026-06-07)


### Bug Fixes

* **deps:** require @playwright/test ^1.60.0 to fix Node.js 26 install hang ([#94](https://github.com/Lullabot/ddev-playwright/issues/94)) ([5dfe8cc](https://github.com/Lullabot/ddev-playwright/commit/5dfe8cc41d51c50cb4392199e6492b3a2a9a029f))

## [0.5.3](https://github.com/Lullabot/ddev-playwright/compare/v0.5.2...v0.5.3) (2026-04-23)


### Features

* trust DDEV's mkcert root CA in Playwright's Chromium, Firefox, and WebKit ([#78](https://github.com/Lullabot/ddev-playwright/issues/78)) ([3a74c69](https://github.com/Lullabot/ddev-playwright/commit/3a74c69d41a0bf5a711da7d9ff30f5f1ec8d62ba))

## [0.5.2](https://github.com/Lullabot/ddev-playwright/compare/v0.5.1...v0.5.2) (2026-03-23)


### Bug Fixes

* manage .gitignore via post_install_actions for addon coexistence ([92a6aa9](https://github.com/Lullabot/ddev-playwright/commit/92a6aa93de137437707966d7bbf9fcbea198e59c))
* preserve both addons' browsers when co-installed with ddev-playwright-cli ([5cf40cd](https://github.com/Lullabot/ddev-playwright/commit/5cf40cd4645299f5f6ea257e76da6185fdd768c5))

## [0.5.1](https://github.com/Lullabot/ddev-playwright/compare/0.5.0...v0.5.1) (2026-03-13)


### Features

* add tmpfs mount for SQLite test databases ([#52](https://github.com/Lullabot/ddev-playwright/issues/52)) ([c39e5dd](https://github.com/Lullabot/ddev-playwright/commit/c39e5dd758cd4f8b20075d0c0aadef233b47bea1))
* install uv Python tool runner in web container ([#53](https://github.com/Lullabot/ddev-playwright/issues/53)) ([e412887](https://github.com/Lullabot/ddev-playwright/commit/e412887265074ec7d54e06704b6b66238253395e))


### Bug Fixes

* improve install-playwright error handling and setup documentation ([#49](https://github.com/Lullabot/ddev-playwright/issues/49)) ([78c4e58](https://github.com/Lullabot/ddev-playwright/commit/78c4e58e973e7c1f7ece16f886e36bce2f18f8f6))
* replace static with portable interpreter path in install script shebang ([#42](https://github.com/Lullabot/ddev-playwright/issues/42)) ([4a1e79c](https://github.com/Lullabot/ddev-playwright/commit/4a1e79cda344311eb51c09de567de1e7eacf472a))
