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
      && ddev exec "nc -zw5 mindsdb 47335" \
      && ddev exec "nc -zw5 mindsdb 47336"; then
      return 0
    fi
    sleep $wait
  done

  echo "MindsDB health checks failed after $((retries * wait)) seconds" >&2
  echo "Running debug diagnostics..." >&2
  show_debug_info
  return 1
}

show_debug_info() {
  echo "=== MindsDB Debug Information ===" >&2

  # Container status
  echo "Container status:" >&2
  ddev logs -s mindsdb | tail -20 >&2

  # Docker container logs
  echo "Docker container logs:" >&2
  docker logs "ddev-${PROJECT}-mindsdb" 2>&1 | tail -30 >&2

  # Container health check
  echo "Health check details:" >&2
  docker inspect --format "{{ json .State.Health }}" "ddev-${PROJECT}-mindsdb" | jq -r '.' 2>/dev/null >&2 || echo "No health data" >&2

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
  ddev restart
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  cd ${TEST_DIR} || ( printf "unable to cd to ${TEST_DIR}\n" && exit 1 )
  echo "# ddev add-on get meevagmbh/ddev-addon-mindsdb with project ${PROJECT} in ${TEST_DIR} ($(pwd))" >&3
  ddev add-on get meevagmbh/ddev-addon-mindsdb
  ddev restart >/dev/null
  health_checks
}
