# Tests for the pre-start hooks in config.playwright.yml.
#
# These run the hook bodies straight out of the YAML, on the host, with no ddev
# project and no Docker build. That keeps them fast, but the real reason they
# exist is #118: a macOS-only bug that Linux CI could never have caught, because
# the difference lives in `cp` itself rather than in anything ddev does. See
# tests/bsd-cp-shim/cp for how we stand in for macOS here.

setup() {
  set -eu -o pipefail
  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH:-}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library 'bats-support'
  bats_load_library 'bats-assert'

  export DIR
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."

  export BSD_CP_PATH="${DIR}/tests/bsd-cp-shim"

  export PROJECT
  PROJECT="$(mktemp -d "${BATS_TMPDIR:-/tmp}/ddev-playwright-prestart.XXXXXXXX")"
}

teardown() {
  [ -n "${PROJECT:-}" ] && rm -rf "${PROJECT}"
}

# A project as it looks after `ddev add-on get` plus an `npm install` in the
# Playwright test directory: dependency manifests, an installed node_modules,
# and the test files that accumulate as the suite grows.
#
# node_modules/.bin holds the relative symlinks npm creates for every package's
# executable, which is where #118 bit: packages rely on them, and
# patch-package's entrypoint does `require('./dist/index.js')`, which only
# resolves because __dirname follows the symlink back to
# node_modules/patch-package/. The hook no longer stages node_modules at all,
# so that class of breakage is now structurally impossible there rather than
# merely avoided — but .yarn/ is still copied as a directory, so the symlink
# handling stays under test through it.
#
# Takes the test directory to build, defaulting to PLAYWRIGHT_TEST_DIR's own
# default of test/playwright.
make_project() {
  local test_dir="${1:-test/playwright}"

  cd "${PROJECT}"
  mkdir -p .ddev/web-build \
    "${test_dir}/node_modules/.bin" \
    "${test_dir}/node_modules/patch-package/dist" \
    "${test_dir}/tests/home.spec.ts-snapshots" \
    "${test_dir}/fixtures" \
    "${test_dir}/.yarn/releases"

  touch .ddev/web-build/disabled.Dockerfile.playwright
  touch .ddev/web-build/Dockerfile.playwright

  echo '{"name":"pw"}' > "${test_dir}/package.json"
  echo '{"lockfileVersion":3}' > "${test_dir}/package-lock.json"
  echo "registry=https://registry.example.com/" > "${test_dir}/.npmrc"

  echo "require('./dist/index.js');" > "${test_dir}/node_modules/patch-package/index.js"
  echo "module.exports = 'ok';" > "${test_dir}/node_modules/patch-package/dist/index.js"
  ln -s ../patch-package/index.js "${test_dir}/node_modules/.bin/patch-package"

  # Yarn Berry keeps its release in .yarn/, and .yarnrc.yml can point at it
  # through a symlink. This is the only directory the hook still copies.
  echo "module.exports = 'yarn';" > "${test_dir}/.yarn/releases/yarn-3.5.1.cjs"
  ln -s yarn-3.5.1.cjs "${test_dir}/.yarn/releases/yarn.cjs"

  # ...alongside state yarn regenerates on every install. A real 3.x project
  # also puts its package cache under .yarn/cache, which is an install input.
  mkdir -p "${test_dir}/.yarn/cache" "${test_dir}/.yarn/unplugged/esbuild"
  echo "zip" > "${test_dir}/.yarn/cache/playwright-npm-1.60.0.zip"
  echo "state" > "${test_dir}/.yarn/install-state.gz"
  echo "built" > "${test_dir}/.yarn/build-state.yml"
  echo "bin" > "${test_dir}/.yarn/unplugged/esbuild/bin"

  echo "spec" > "${test_dir}/tests/home.spec.ts"
  echo "baseline" > "${test_dir}/tests/home.spec.ts-snapshots/home-chromium-linux.png"
  echo "fixture" > "${test_dir}/fixtures/database.sql"
}

# Run each exec-host pre-start hook the way ddev does: one bash invocation per
# hook, from the project root. PATH is pointed at the macOS cp stand-in.
run_pre_start_hooks() {
  cd "${PROJECT}"

  local count index script
  count="$(yq -r '.hooks["pre-start"] | length' "${DIR}/config.playwright.yml")"

  for (( index = 0; index < count; index++ )); do
    script="$(yq -r ".hooks[\"pre-start\"][${index}][\"exec-host\"]" "${DIR}/config.playwright.yml")"
    [ "${script}" = "null" ] && continue
    PATH="${BSD_CP_PATH}:${PATH}" bash -c "${script}"
  done
}

@test "pre-start stages the dependency manifests" {
  make_project
  run_pre_start_hooks

  local staged=".ddev/web-build/playwright"
  assert [ -f "${staged}/package.json" ]
  assert [ -f "${staged}/package-lock.json" ]
  assert [ -f "${staged}/.npmrc" ]
  assert [ -d "${staged}/.yarn" ]
}

@test "pre-start stages nothing that only churns with test authoring" {
  make_project
  run_pre_start_hooks

  # Dockerfile.playwright bind-mounts this directory into the build, so
  # everything here lands in the browser-install layer's cache key and in every
  # layer after it. None of these files are needed to install browsers, and the
  # layer deletes its copy of the tree anyway, so staging them would rebuild the
  # web image every time a spec or a baseline screenshot changed.
  local staged=".ddev/web-build/playwright"
  refute [ -e "${staged}/node_modules" ]
  refute [ -e "${staged}/tests" ]
  refute [ -e "${staged}/fixtures" ]
}

@test "pre-start stages yarn's install inputs but not its build products" {
  make_project
  run_pre_start_hooks

  # .yarn/ holds both. releases/, patches/, plugins/ and cache/ are read
  # during install; the rest is regenerated by it, and staging build products
  # would put them in the browser layer's cache key.
  local staged=".ddev/web-build/playwright/.yarn"
  assert [ -d "${staged}/releases" ]
  assert [ -f "${staged}/cache/playwright-npm-1.60.0.zip" ]
  refute [ -e "${staged}/install-state.gz" ]
  refute [ -e "${staged}/build-state.yml" ]
  refute [ -e "${staged}/unplugged" ]
}

@test "pre-start stages a local tarball dependency" {
  make_project
  cd "${PROJECT}"
  echo "tarball" > test/playwright/some-package-1.0.0.tgz

  run_pre_start_hooks

  # npm records a local tarball as a path relative to the package directory, so
  # it has to be staged alongside the manifests or the build's install fails
  # with ENOENT.
  assert [ -f ".ddev/web-build/playwright/some-package-1.0.0.tgz" ]
}

@test "pre-start stages symlinks as symlinks" {
  make_project
  run_pre_start_hooks

  # #118 was BSD `cp -r` flattening a symlink into a copy of its target. That
  # bug reached node_modules, which is no longer staged, but .yarn/ is still
  # copied as a directory and the flag choice has to stay correct for it.
  local copied=".ddev/web-build/playwright/.yarn/releases/yarn.cjs"
  assert [ -L "${copied}" ]
  assert_equal "$(readlink "${copied}")" "yarn-3.5.1.cjs"
}

@test "pre-start stages from a custom PLAYWRIGHT_TEST_DIR too" {
  make_project tests/e2e
  cd "${PROJECT}"
  echo "PLAYWRIGHT_TEST_DIR=tests/e2e" > .ddev/.env

  run_pre_start_hooks

  local staged=".ddev/web-build/playwright"
  assert [ -f "${staged}/package.json" ]
  assert [ -L "${staged}/.yarn/releases/yarn.cjs" ]
  refute [ -e "${staged}/node_modules" ]
}

@test "pre-start fails loudly when the manifests are missing" {
  make_project
  cd "${PROJECT}"
  rm test/playwright/package.json

  # Without a package.json the build's install has nothing to pin Playwright
  # to, and `playwright install` would quietly fetch whatever version is
  # current instead of the one the project locked. Failing the start is louder
  # than shipping an image with mismatched browsers.
  run run_pre_start_hooks
  assert_failure
  assert_output --partial "package.json is missing"
}

@test "pre-start enables the playwright Dockerfile from the disabled copy" {
  make_project
  cd "${PROJECT}"
  echo "FROM scratch" > .ddev/web-build/disabled.Dockerfile.playwright
  : > .ddev/web-build/Dockerfile.playwright

  run_pre_start_hooks

  assert_equal "$(cat .ddev/web-build/Dockerfile.playwright)" "FROM scratch"
}

@test "pre-start is a no-op when playwright is not enabled" {
  make_project
  cd "${PROJECT}"
  rm .ddev/web-build/Dockerfile.playwright

  run_pre_start_hooks

  refute [ -e .ddev/web-build/playwright ]
  refute [ -e .ddev/web-build/Dockerfile.playwright ]
}

# Guards the test above: if the stand-in ever stops flattening symlinks under
# `-r`, that test would pass no matter what config.playwright.yml does.
@test "the macOS cp stand-in flattens symlinks under -r but not -a" {
  make_project
  cd "${PROJECT}"

  PATH="${BSD_CP_PATH}:${PATH}" cp -r test/playwright copied-with-r
  PATH="${BSD_CP_PATH}:${PATH}" cp -a test/playwright copied-with-a

  assert [ -f copied-with-r/node_modules/.bin/patch-package ]
  refute [ -L copied-with-r/node_modules/.bin/patch-package ]
  assert [ -L copied-with-a/node_modules/.bin/patch-package ]
}
