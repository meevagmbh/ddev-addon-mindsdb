# ddev-addon-mindsdb - MindsDB DDEV Add-on

This is a DDEV add-on that provides MindsDB, an open-source AI layer for databases that enables machine learning model development using SQL. The add-on runs MindsDB as a containerized service within DDEV projects.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Bootstrap and Setup Requirements
- Install DDEV (Local Development Environment for Docker):
  ```bash
  curl -fsSL https://raw.githubusercontent.com/ddev/ddev/master/scripts/install_ddev.sh | bash
  ```
- Install BATS (Bash Automated Testing System) for running tests:
  ```bash
  sudo apt update && sudo apt install -y bats
  ```
- Verify installations:
  ```bash
  ddev --version  # Should show v1.24.8+
  bats --version  # Should show v1.10.0+
  docker --version  # Required for DDEV
  ```

### Testing the Add-on
- **CRITICAL**: Run the complete test suite to validate functionality:
  ```bash
  bats tests/test.bats
  ```
- **NEVER CANCEL**: MindsDB container startup takes 2-5 minutes. NEVER CANCEL. Set timeout to 15+ minutes.
- **TIMING EXPECTATION**: Complete test suite takes 10-15 minutes total due to container startup time.

### Manual Testing and Validation
- Create a test DDEV project and install the add-on:
  ```bash
  mkdir /tmp/test-mindsdb && cd /tmp/test-mindsdb
  ddev config --project-name=test-mindsdb --omit-containers=db --disable-upload-dirs-warning
  ddev add-on get /home/runner/work/ddev-addon-mindsdb/ddev-addon-mindsdb
  ddev restart
  ```
- **NEVER CANCEL**: `ddev restart` takes 2-5 minutes on first run. NEVER CANCEL. Set timeout to 15+ minutes.
- **CLEANUP**: Always clean up test projects: `ddev delete -Oy && rm -rf /tmp/test-mindsdb`

## Validation Scenarios

### ALWAYS Test These Scenarios After Making Changes
1. **Container Health Check**:
   ```bash
   # Wait for container to be fully ready (15-20 minutes)
   docker ps | grep mindsdb  # Should show running container
   ```

2. **MindsDB API Validation**:
   ```bash
   # Test MindsDB API endpoint (used by health checks)
   docker exec ddev-[project]-mindsdb curl -s http://localhost:47334/api/util/ping
   ```
   - **Expected**: Should return `{"status": "ok"}`
   - **Manual**: Access `http://test-mindsdb.ddev.site:47334/` in browser for web interface

3. **MySQL API Port Validation**:
   ```bash
   # Test MySQL API port availability using Python (nc not available in container)
   docker exec ddev-[project]-mindsdb python -c "import socket; s=socket.socket(); s.connect(('localhost', 47335)); s.close(); print('MySQL port accessible')"
   ```
   - **Expected**: Should print "MySQL port accessible"

4. **Container Process Validation**:
   ```bash
   # Verify MindsDB processes are running
   docker exec ddev-test-mindsdb-mindsdb ps aux | grep -E "(python|mindsdb)"
   ```

### Debug and Troubleshooting
- Use the provided debug script for container issues:
  ```bash
  ./.ddev/debug-mindsdb.sh [project-name]
  ```
- Check container logs if startup fails:
  ```bash
  ddev logs -s mindsdb
  docker logs ddev-[project]-mindsdb
  ```
- **COMMON ISSUE**: Container startup failure - Usually resolved by waiting longer or restarting
- **SOLUTION**: Run `ddev restart` and wait full 5 minutes
- **TEST VALIDATION**: Use `bats --count tests/test.bats` to verify test structure (should show "2")

## Key Architecture Components

### Container Configuration (docker-compose.mindsdb.yaml)
- **Image**: `mindsdb/mindsdb:${MINDSDB_DOCKER_TAG:-lightwood}`
- **HTTP API Port**: 47334 (MindsDB Studio web interface)
- **MySQL Port**: 47335 (SQL API endpoint)
- **Health Check**: Python-based API ping with 90s start period
- **Startup Time**: 2-5 minutes for full initialization

### Configuration Files
- `mindsdb_config.json`: MindsDB service configuration
- `install.yaml`: DDEV add-on installation manifest
- `tests/test.bats`: Automated test suite (2 tests: directory install, release install)

### Development Workflow
1. **ALWAYS** run tests before committing changes:
   ```bash
   bats tests/test.bats  # Takes 10-15 minutes total
   ```
2. **TIMING**: Set timeouts of 15+ minutes for any test command
3. **VALIDATION**: Always verify both web interface and MySQL API after changes
4. **DEBUGGING**: Use debug script for any container startup issues

## Common Tasks

### Repo Structure
```
.
├── .github/
│   └── workflows/tests.yml      # CI/CD pipeline using ddev/github-action-add-on-test@v2
├── README.md                    # Installation and basic usage instructions
├── install.yaml                 # DDEV add-on configuration
├── docker-compose.mindsdb.yaml  # MindsDB service definition
├── mindsdb_config.json         # MindsDB configuration
├── debug-mindsdb.sh            # Debugging script for container issues
├── tests/
│   └── test.bats               # BATS test suite (2 tests)
└── LICENSE                     # Apache 2.0 license
```

### Frequently Used Commands
```bash
# Test add-on functionality
bats tests/test.bats  # NEVER CANCEL: 10-15 minutes total

# Debug container issues  
./debug-mindsdb.sh [project-name]

# Check container status
docker ps -a | grep mindsdb

# View container logs
ddev logs -s mindsdb
docker logs ddev-[project]-mindsdb

# Manual add-on installation test
ddev add-on get meevagmbh/ddev-addon-mindsdb
ddev restart  # NEVER CANCEL: 2-5 minutes
```

### Environment Variables
- `MINDSDB_DOCKER_TAG`: Override MindsDB Docker image tag (default: `lightwood`)
- `DDEV_NON_INTERACTIVE=true`: Required for automated testing

## Critical Timing Information
- **Container Startup**: 2-5 minutes for MindsDB initialization (validated)
- **Health Check Start Period**: 90 seconds before health checks begin
- **Test Suite Total Time**: 10-15 minutes (includes 2 container startups)
- **NEVER CANCEL WARNING**: Always wait for full startup completion
- **Recommended Timeouts**: 15+ minutes for any container operation