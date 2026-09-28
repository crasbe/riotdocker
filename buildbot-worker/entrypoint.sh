#!/bin/sh
# Container entrypoint: connects this container to a Buildbot master as a
# worker and runs it in the foreground, so its output goes to the container
# log. Configured entirely through the environment (see README.md).
set -e

WORKER_DIR=${BUILDBOT_WORKER_DIR:-/data/riotbuild/worker}
MASTER=${BUILDBOT_MASTER_HOST:?BUILDBOT_MASTER_HOST is required}:${BUILDBOT_MASTER_PORT:-9989}
NAME=${BUILDBOT_WORKER_NAME:?BUILDBOT_WORKER_NAME is required}
PASSWORD=${BUILDBOT_WORKER_PASSWORD:?BUILDBOT_WORKER_PASSWORD is required}

# RIOT's package/git cache; shared across builds via the /cache volume.
git-cache init || {
    echo "Error initializing git-cache. Permission problem?"
    exit 1
}

# Only register with the master once; WORKER_DIR persists across container
# restarts via the /data/riotbuild volume mount.
[ -f "${WORKER_DIR}/buildbot.tac" ] || \
    buildbot-worker create-worker "${WORKER_DIR}" "${MASTER}" "${NAME}" "${PASSWORD}"

exec buildbot-worker start --nodaemon "${WORKER_DIR}"
