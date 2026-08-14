setup() {
  set -eu -o pipefail
  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH:-}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library 'bats-support'
  bats_load_library 'bats-assert'
  export DIR
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."

  export DDEV_NON_INTERACTIVE=true

  echo "# user is ${USER}" >&3

  # Every run gets its own directory and its own project names. With a fixed
  # TESTDIR and PROJNAME, two concurrent runs of this suite -- two developers
  # or agents on one workstation, or two jobs on one self-hosted runner --
  # share both. One run's teardown then rm -rf's the directory the other is
  # working in, and the damage surfaces somewhere unrelated, as a
  # "getwd: no such file or directory" out of whichever ddev command runs next.
  #
  # This isolates the filesystem and project namespace only. Concurrent runs
  # still share one Docker daemon and one ddev router, so they can still
  # contend; this makes them non-destructive, not free.
  mkdir -p "${HOME}/tmp"
  export TESTDIR
  TESTDIR=$(mktemp -d "${HOME}/tmp/test-addon-ddev-playwright.XXXXXXXXX")
  echo "# testdir is ${TESTDIR}" >&3

  # mktemp's suffix is mixed case; ddev project names are [a-z0-9-], so fold it
  # down rather than handing ddev a name it rejects.
  RUN_ID=$(printf '%s' "${TESTDIR##*.}" | tr '[:upper:]' '[:lower:]')
  export PROJNAME="test-addon-ddev-playwright-${BATS_SUITE_TEST_NUMBER}-${RUN_ID}"
  export DDEV_NON_INTERACTIVE=true

  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  mkdir -p web
  echo "# configuring project..." >&3
  ddev config --project-name="${PROJNAME}" --docroot=web --project-type=php

  echo "# ddev start" >&3
  ddev start -y >/dev/null
}

health_checks() {
  # Do something useful here that verifies the add-on
  ddev exec "curl -s https://localhost:443/ | grep -q phpinfo"
}

teardown() {
  set -eu -o pipefail
  cd "${TESTDIR}" || ( printf "unable to cd to %s\n" "${TESTDIR}" && exit 1 )
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  # Leave TESTDIR before removing it. Deleting the current working directory
  # leaves this shell with a cwd that no longer resolves, and the next command
  # to call getcwd() -- often something several steps later, in ddev -- dies
  # with "no such file or directory".
  cd "${HOME}"
  if [ -n "${TESTDIR:-}" ] && [ -d "${TESTDIR}" ]; then
    rm -rf "${TESTDIR}"
  fi
}

get_addon() {
  set -eu -o pipefail
  cd "${TESTDIR}"
  echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get "${DIR}"
  assert [ -f .ddev/config.playwright.yml ]
  assert [ -f .ddev/commands/host/install-playwright ]
  assert [ -f .ddev/commands/web/playwright ]
  assert [ -f .ddev/web-build/.gitignore ]
  assert [ -f .ddev/web-build/disabled.Dockerfile.playwright ]
  assert [ -x .ddev/web-build/install-kasmvnc.sh ]
  assert [ -f .ddev/web-build/Dockerfile.task ]
  assert [ -x .ddev/web-build/install-task.sh ]
  assert [ -f .ddev/web-build/kasmvnc.yaml ]
  assert [ -f .ddev/web-build/xstartup ]
  mkdir "${1:-test}"
}

verify_run_playwright() {
  local playwright_dir="${1:-test/playwright}"
  cp -av "$DIR"/tests/testdata/web/* web/
  assert [ -f web/index.php ]
  ddev install-playwright

  ddev exec -- which task

  mkdir -p "${playwright_dir}/tests"
  cp "$DIR"/tests/testdata/phpinfo.spec.ts "${playwright_dir}/tests/phpinfo.spec.ts"
  health_checks

  # Verify kasmvnc is listening.
  curl -s https://"${PROJNAME}".ddev.site:8444/
  curl -s --user "$USER":secret https://"${PROJNAME}.ddev.site:8444/"
  ddev logs
  echo "#" curl -s --user "$USER":secret https://"${PROJNAME}.ddev.site:8444/" >&3
  curl -s --user "$USER":secret https://"${PROJNAME}.ddev.site:8444/" | grep -q KasmVNC

  # Verify that browsers have been downloaded.
  ddev exec -- ls \~/.cache/ms-playwright
  run ddev exec -- ls \~/.cache/ms-playwright \| wc -l \| sed \'s/ *//\'
  # Playwright currently supports 5 browsers.
  assert_output 5

  # Verify we can run an example test.
  ddev playwright test --reporter=line
}

@test "install from directory with npm" {
  get_addon
  cp -av "$DIR"/tests/testdata/npm-playwright test/playwright
  ddev exec -d /var/www/html/test/playwright npm ci
  verify_run_playwright
}

@test "install from directory with yarn" {
  get_addon
  cp -av "$DIR"/tests/testdata/yarn-playwright test/playwright
  verify_run_playwright
}

@test "install from directory with npm and custom PLAYWRIGHT_TEST_DIR (tests/playwright)" {
  get_addon tests
  echo "PLAYWRIGHT_TEST_DIR=tests/playwright" > .ddev/.env
  cp -av "$DIR"/tests/testdata/npm-playwright tests/playwright
  ddev exec -d /var/www/html/tests/playwright npm ci
  verify_run_playwright tests/playwright
}

@test "install requires a playwright installation" {
  set -eu -o pipefail
  cd "${TESTDIR}"
  echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get "${DIR}"
  run ddev install-playwright
  assert_failure
}

#@test "install from release" {
#  set -eu -o pipefail
#  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
#  echo "# ddev get ddev/ddev-addon-template with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
#  ddev get ddev/ddev-addon-template
#  ddev restart >/dev/null
#  health_checks
#}
#
#
