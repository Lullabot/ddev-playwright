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
# Playwright test directory. npm links every package's executable into
# node_modules/.bin as a relative symlink, and packages rely on that:
# patch-package's entrypoint does `require('./dist/index.js')`, which only
# resolves because __dirname follows the symlink back to
# node_modules/patch-package/.
#
# Takes the test directory to build, defaulting to PLAYWRIGHT_TEST_DIR's own
# default of test/playwright.
make_project() {
  local test_dir="${1:-test/playwright}"

  cd "${PROJECT}"
  mkdir -p .ddev/web-build \
    "${test_dir}/node_modules/.bin" \
    "${test_dir}/node_modules/patch-package/dist"

  touch .ddev/web-build/disabled.Dockerfile.playwright
  touch .ddev/web-build/Dockerfile.playwright

  echo "require('./dist/index.js');" > "${test_dir}/node_modules/patch-package/index.js"
  echo "module.exports = 'ok';" > "${test_dir}/node_modules/patch-package/dist/index.js"
  ln -s ../patch-package/index.js "${test_dir}/node_modules/.bin/patch-package"
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

@test "pre-start copies test/playwright without breaking node_modules symlinks" {
  make_project
  run_pre_start_hooks

  local copied=".ddev/web-build/playwright/node_modules/.bin/patch-package"
  assert [ -e "${copied}" ]
  assert [ -L "${copied}" ]
  assert_equal "$(readlink "${copied}")" "../patch-package/index.js"

  # The symptom reported in #118: once the symlink has been flattened into a
  # plain file, node resolves ./dist/index.js against .bin/ and the build dies
  # with "Cannot find module './dist/index.js'".
  if command -v node >/dev/null 2>&1; then
    run node "${copied}"
    assert_success
  fi
}

@test "pre-start preserves symlinks from a custom PLAYWRIGHT_TEST_DIR too" {
  make_project tests/e2e
  cd "${PROJECT}"
  echo "PLAYWRIGHT_TEST_DIR=tests/e2e" > .ddev/.env

  run_pre_start_hooks

  local copied=".ddev/web-build/playwright/node_modules/.bin/patch-package"
  assert [ -L "${copied}" ]
  assert_equal "$(readlink "${copied}")" "../patch-package/index.js"
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
