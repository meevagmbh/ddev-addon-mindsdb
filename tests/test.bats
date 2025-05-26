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
  return 1
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
