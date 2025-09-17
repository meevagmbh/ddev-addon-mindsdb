setup() {
  set -eu -o pipefail

  export ADDON_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)/.."
  export PROJECT=ddev-addon-mindsdb
  export TEST_DIR="$HOME/tmp/$PROJECT"
  export DDEV_NON_INTERACTIVE=true

  mkdir -p $TEST_DIR && cd "$TEST_DIR" || (printf "unable to cd to $TEST_DIR\n" && exit 1)

  ddev delete -Oy $PROJECT >/dev/null 2>&1 || true
  ddev config --project-name=$PROJECT --omit-containers=db --disable-upload-dirs-warning
}

health_checks() {
  local retries=30
  local wait=2

  for i in $(seq 1 $retries); do
    if ddev exec "curl -s http://mindsdb:47334/" | grep -io 'mindsdb studio' \
      && ddev exec "nc -zw5 mindsdb 47335"; then
      return 0
    fi
    sleep $wait
  done

  echo "MindsDB health checks failed after $((retries * wait)) seconds" >&2
  echo "Running debug diagnostics..." >&2
  show_debug_info
  return 1
}

show_debug_info_on_startup_failure() {
  echo "=== MindsDB Startup Failure Debug Information ===" >&3

  # Run the exact commands from DDEV error message for CI debugging
  echo "Running DDEV-suggested debug commands:" >&3
  echo "----------------------------------------" >&3

  echo "1. ddev logs -s mindsdb:" >&3
  ddev logs -s mindsdb >&3 2>&3 || echo "Failed to get ddev logs" >&3
  echo "" >&3

  echo "2. docker logs ddev-${PROJECT}-mindsdb:" >&3
  docker logs "ddev-${PROJECT}-mindsdb" 2>&1 >&3 || echo "Failed to get docker logs" >&3
  echo "" >&3

  echo "3. docker inspect health check:" >&3
  docker inspect --format "{{ json .State.Health }}" "ddev-${PROJECT}-mindsdb" | docker run -i --rm ddev/ddev-utilities jq -r >&3 2>&3 || echo "Failed to inspect health check" >&3
  echo "" >&3

  # Additional debugging info
  echo "Additional container info:" >&3
  echo "-------------------------" >&3
  docker ps -a --filter "name=ddev-${PROJECT}-mindsdb" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" >&3 2>&3 || echo "Failed to get container status" >&3
  echo "" >&3

  # Container exit code and state
  echo "Container exit details:" >&3
  docker inspect --format "ExitCode: {{.State.ExitCode}}, Error: {{.State.Error}}, Status: {{.State.Status}}" "ddev-${PROJECT}-mindsdb" >&3 2>&3 || echo "Failed to get container exit details" >&3
  echo "" >&3
}

show_debug_info() {
  echo "=== MindsDB Debug Information ===" >&2

  # Run the exact commands from DDEV error message for CI debugging
  echo "Running DDEV-suggested debug commands:" >&2
  echo "----------------------------------------" >&2

  echo "1. ddev logs -s mindsdb:" >&2
  ddev logs -s mindsdb >&2 || echo "Failed to get ddev logs" >&2
  echo "" >&2

  echo "2. docker logs ddev-${PROJECT}-mindsdb:" >&2
  docker logs "ddev-${PROJECT}-mindsdb" 2>&1 >&2 || echo "Failed to get docker logs" >&2
  echo "" >&2

  echo "3. docker inspect health check:" >&2
  docker inspect --format "{{ json .State.Health }}" "ddev-${PROJECT}-mindsdb" | docker run -i --rm ddev/ddev-utilities jq -r >&2 || echo "Failed to inspect health check" >&2
  echo "" >&2

  # Additional debugging info
  echo "Additional container info:" >&2
  echo "-------------------------" >&2
  docker ps -a --filter "name=ddev-${PROJECT}-mindsdb" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" >&2 || echo "Failed to get container status" >&2

  # Run debug script if available
  if [ -f "${ADDON_DIR}/debug-mindsdb.sh" ]; then
    echo "Running full debug script:" >&2
    "${ADDON_DIR}/debug-mindsdb.sh" "${PROJECT}" >&2
  fi
}

teardown() {
  set -eu -o pipefail
  cd "$TEST_DIR" || (printf "unable to cd to $TEST_DIR\n" && exit 1)
  ddev stop
  ddev delete -Oy "$PROJECT" >/dev/null 2>&1
  [ "$TEST_DIR" != "" ] && rm -rf "$TEST_DIR"
}

@test "install from directory" {
  set -eu -o pipefail
  cd ${TEST_DIR}
  echo "# ddev add-on get ${TEST_DIR} with project ${PROJECT} in ${TEST_DIR} ($(pwd))" >&3
  ddev add-on get ${ADDON_DIR}

  # Try to restart and capture debug info if it fails
  if ! ddev restart; then
    echo "ddev restart failed, running debug commands:" >&3
    show_debug_info_on_startup_failure
    return 1
  fi

  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  cd ${TEST_DIR} || ( printf "unable to cd to ${TEST_DIR}\n" && exit 1 )
  echo "# ddev add-on get meevagmbh/ddev-addon-mindsdb with project ${PROJECT} in ${TEST_DIR} ($(pwd))" >&3
  ddev add-on get meevagmbh/ddev-addon-mindsdb

  # Try to restart and capture debug info if it fails
  if ! ddev restart >/dev/null 2>&1; then
    echo "ddev restart failed, running debug commands:" >&3
    show_debug_info_on_startup_failure
    return 1
  fi

  health_checks
}
