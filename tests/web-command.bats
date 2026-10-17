# Exercise the real command from a non-root working directory without Docker.
setup() {
  COMMAND="${BATS_TEST_DIRNAME}/../commands/web/playwright"
  export DDEV_APPROOT="${BATS_TEST_TMPDIR}/project root"
  mkdir -p "$DDEV_APPROOT/docroot" "$DDEV_APPROOT/test/playwright" "$BATS_TEST_TMPDIR/bin"
  unset PLAYWRIGHT_TEST_DIR

  # Record both dependency installation and execution, including their cwd.
  for tool in npm npx yarn; do
    cat > "$BATS_TEST_TMPDIR/bin/$tool" <<'SH'
#!/bin/sh
printf '%s|%s|%s\n' "${0##*/}" "$PWD" "$*"
SH
    chmod +x "$BATS_TEST_TMPDIR/bin/$tool"
  done
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  cd "$DDEV_APPROOT/docroot"
}

@test "default test directory resolves from project root with a custom working_dir" {
  run sh "$COMMAND" test --list
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "npm|$DDEV_APPROOT/test/playwright|ci" ]
  [ "${lines[1]}" = "npx|$DDEV_APPROOT/test/playwright|playwright test --list" ]
}

@test "custom relative test directory resolves from project root for yarn" {
  export PLAYWRIGHT_TEST_DIR="tests/custom playwright"
  mkdir -p "$DDEV_APPROOT/$PLAYWRIGHT_TEST_DIR"
  touch "$DDEV_APPROOT/$PLAYWRIGHT_TEST_DIR/yarn.lock"
  run sh "$COMMAND" test --list
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "yarn|$DDEV_APPROOT/$PLAYWRIGHT_TEST_DIR|" ]
  [ "${lines[1]}" = "yarn|$DDEV_APPROOT/$PLAYWRIGHT_TEST_DIR|playwright test --list" ]
}

@test "absolute test directory remains supported" {
  export PLAYWRIGHT_TEST_DIR="$BATS_TEST_TMPDIR/absolute playwright"
  mkdir -p "$PLAYWRIGHT_TEST_DIR"
  run sh "$COMMAND" test --list
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "npx|$PLAYWRIGHT_TEST_DIR|playwright test --list" ]
}

@test "missing project root fails before running the package manager" {
  export DDEV_APPROOT="$BATS_TEST_TMPDIR/missing"
  run sh "$COMMAND" test --list
  [ "$status" -eq 1 ]
  [[ "$output" != *"npm|"* ]]
  [[ "$output" != *"npx|"* ]]
}
