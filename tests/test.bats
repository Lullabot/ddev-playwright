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
  assert [ -f .ddev/web-build/Dockerfile.10-go-task ]
  assert [ -f .ddev/web-build/Dockerfile.20-astral-uv ]
  assert [ -x .ddev/web-build/install-task.sh ]
  assert [ -f .ddev/web-build/kasmvnc.yaml ]
  assert [ -f .ddev/web-build/xstartup ]
  mkdir "${1:-test}"
}

# Fill the Playwright directory with the bulky, frequently-changing files a
# real project accumulates: fixtures and snapshot baselines. None of them are
# needed to install browsers, so the pre-start hook must leave them out of the
# build context. Seeding them here proves the build still works when the only
# thing staged is the dependency manifests.
seed_test_artifacts() {
  local playwright_dir="${1:-test/playwright}"
  mkdir -p "${playwright_dir}/fixtures"
  mkdir -p "${playwright_dir}/tests/phpinfo.spec.ts-snapshots"
  head -c 1048576 /dev/urandom > "${playwright_dir}/fixtures/database.sql"
  head -c 1048576 /dev/urandom > "${playwright_dir}/tests/phpinfo.spec.ts-snapshots/phpinfo-chromium-linux.png"
}

verify_run_playwright() {
  local playwright_dir="${1:-test/playwright}"
  cp -av "$DIR"/tests/testdata/web/* web/
  assert [ -f web/index.php ]
  seed_test_artifacts "${playwright_dir}"
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
  #
  # Assert the expected browsers are present rather than counting directories.
  # The browser cache is deliberately allowed to hold more than one Playwright
  # version's browsers: disabled.Dockerfile.playwright sets
  # PLAYWRIGHT_SKIP_BROWSER_GC=1 so that browsers installed by a different
  # playwright-core version -- @playwright/cli from ddev-playwright-cli, say --
  # survive this install. Any fixed count therefore encodes an assumption the
  # add-on goes out of its way to break, and fails as soon as a second version
  # is present (locally, via the shared /ms-playwright-cache BuildKit mount;
  # in CI, for anyone co-installing ddev-playwright-cli).
  #
  # A count is also weaker than it looks: five directories still passes if they
  # are the wrong five. These patterns check what the test actually means.
  run ddev exec -- ls \~/.cache/ms-playwright
  assert_success
  assert_line --regexp '^chromium-[0-9]+$'
  assert_line --regexp '^chromium_headless_shell-[0-9]+$'
  assert_line --regexp '^firefox-[0-9]+$'
  assert_line --regexp '^webkit-[0-9]+$'
  assert_line --regexp '^ffmpeg-[0-9]+$'

  assert_invariant_layers_precede_browser_install

  # Verify we can run an example test. The reporters come from
  # playwright.config.ts (line + html); the html one leaves behind a report for
  # verify_show_report to serve.
  ddev playwright test

  verify_show_report
}

# Assert through the routed URL, not the container port: a request straight to
# 9323 succeeds whichever interface the report server bound, so it would not
# catch https://github.com/Lullabot/ddev-playwright/issues/103. See the comment
# above report_advice in commands/web/playwright for why the binding matters.
verify_show_report() {
  local log="${TESTDIR}/show-report.log"
  local url="https://${PROJNAME}.ddev.site:9324"

  ddev playwright show-report >"${log}" 2>&1 &
  local report_pid=$!

  local code=""
  # `ddev playwright show-report` reinstalls dependencies before it starts the
  # server -- `npm ci` deletes and rebuilds node_modules every time, which is
  # pure waste for a subcommand that only serves a directory. Until that is
  # fixed this budget has to cover a full install on a loaded runner, not just
  # the few seconds the report server itself needs.
  #
  # --max-time keeps that budget honest: without it a router that accepts and
  # then hangs would stretch each attempt out to curl's own default timeout.
  for _ in $(seq 1 60); do
    code=$(curl -sk --max-time 5 -o /dev/null -w '%{http_code}' "${url}/" || true)
    if [ "${code}" = "200" ]; then
      break
    fi
    sleep 2
  done

  kill "${report_pid}" >/dev/null 2>&1 || true
  wait "${report_pid}" >/dev/null 2>&1 || true
  # Killing the host-side `ddev` leaves the report server running inside the
  # container, holding port 9323 against the next test in this project.
  #
  # `ddev exec` runs this through a shell, so the wrapper's own command line
  # contains the pattern and pkill -f would match -- and signal -- its own
  # parent. The bracket makes the pattern match the report server without
  # matching the literal text of the pkill invocation.
  ddev exec -- pkill -f '[p]laywright.*show-report' >/dev/null 2>&1 || true

  echo "# show-report log:" >&3
  sed 's/^/# /' "${log}" >&3

  # The URL the user is meant to open, printed above Playwright's own
  # "Serving HTML report at http://0.0.0.0:9323" line.
  run cat "${log}"
  assert_output --partial "view the report at ${url}"

  assert_equal "${code}" "200"
}

# Guard the Dockerfile layer ordering.
#
# The browser install bind-mounts the staged Playwright directory, and BuildKit
# folds a bind mount's contents into that layer's cache key -- so every
# instruction after it is invalidated whenever that directory changes. Anything
# not derived from the user's Playwright directory therefore has to come first,
# or it gets rebuilt for no reason. See the note at the top of
# disabled.Dockerfile.playwright.
#
# This reads the Dockerfile DDEV generates rather than timing a build, so it is
# deterministic and costs milliseconds. It would not survive someone
# "tidying" the Dockerfile back into a more natural-looking order, which is
# exactly the regression it exists to catch.
assert_invariant_layers_precede_browser_install() {
  local dockerfile=".ddev/.webimageBuild/Dockerfile"
  assert [ -f "$dockerfile" ]

  local bind_line
  bind_line=$(grep -n 'source=./playwright' "$dockerfile" | head -1 | cut -d: -f1)
  assert [ -n "$bind_line" ]

  local marker line
  for marker in 'libnss3-tools' 'install-kasmvnc.sh' 'install-task.sh' 'astral.sh/uv'; do
    line=$(grep -n "$marker" "$dockerfile" | tail -1 | cut -d: -f1)
    if [ -z "$line" ]; then
      batslib_print_kv_single 8 'missing marker' "$marker" | batslib_decorate 'marker not found in generated Dockerfile' | fail
    fi
    if [ "$line" -ge "$bind_line" ]; then
      { batslib_print_kv_single 12 'marker' "$marker" 'marker line' "$line" 'bind mount line' "$bind_line"
      } | batslib_decorate 'invariant layer must precede the bind-mounted browser install' | fail
    fi
  done
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
