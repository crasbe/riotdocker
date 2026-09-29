#!/bin/sh
# Container entrypoint: connects BUILDBOT_WORKER_COUNT workers to a Buildbot
# dispatcher and runs them in the foreground. Each worker runs one build at a
# time; all of them share the container's caches (ccache, git-cache,
# dlcache). Configured entirely through the environment (see README.md).
set -e

NAME=${BUILDBOT_WORKER_NAME:?BUILDBOT_WORKER_NAME is required}
PASSWORD=${BUILDBOT_WORKER_PASSWORD:?BUILDBOT_WORKER_PASSWORD is required}
DISPATCHER=${BUILDBOT_DISPATCHER_HOST:?BUILDBOT_DISPATCHER_HOST is required}:${BUILDBOT_DISPATCHER_PORT:-9989}
COUNT=${BUILDBOT_WORKER_COUNT:-1}
WORKERS_DIR=/data/riotbuild/workers

# Keep ccache below the size of its tmpfs, so ccache's own cleanup kicks in
# before the tmpfs runs full.
if [ -n "${BUILDBOT_CCACHE_GIGS}" ] && [ -z "${CCACHE_MAXSIZE}" ]; then
    export CCACHE_MAXSIZE="$((BUILDBOT_CCACHE_GIGS * 900))M"
fi

# git-cache and dlcache live on the persistent /cache volume.
mkdir -p "${GIT_CACHE_DIR}" "${DLCACHE_DIR}" || {
    echo "Cannot create ${GIT_CACHE_DIR} and ${DLCACHE_DIR}. Permission problem?"
    exit 1
}

pids=""
i=1
while [ "${i}" -le "${COUNT}" ]; do
    # The dispatcher accepts "<name>-1" up to "<name>-<max>".
    name="${NAME}-${i}"
    dir="${WORKERS_DIR}/${name}"
    # Recreated on every start so name, password or dispatcher changes apply.
    mkdir -p "${dir}"
    rm -f "${dir}/buildbot.tac"
    buildbot-worker create-worker --force "${dir}" "${DISPATCHER}" "${name}" "${PASSWORD}"
    echo "starting worker ${name}"
    buildbot-worker start --nodaemon "${dir}" &
    pids="${pids} $!"
    i=$((i + 1))
done

stopping=0
trap 'stopping=1; kill ${pids} 2>/dev/null' TERM INT

# If one worker process dies, stop all of them, so the container exits and
# Docker's restart policy brings the whole set back up.
while :; do
    for pid in ${pids}; do
        if ! kill -0 "${pid}" 2>/dev/null; then
            [ "${stopping}" = 1 ] || echo "worker process ${pid} exited, stopping"
            # shellcheck disable=SC2086
            kill ${pids} 2>/dev/null || true
            wait
            [ "${stopping}" = 1 ] && exit 0
            exit 1
        fi
    done
    sleep 5
done
