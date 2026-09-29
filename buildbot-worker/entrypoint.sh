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
dirs=""
logs=""
i=1
while [ "${i}" -le "${COUNT}" ]; do
    # The dispatcher accepts "<name>-1" up to "<name>-<max>".
    name="${NAME}-${i}"
    dir="${WORKERS_DIR}/${name}"
    # Recreated on every start so name, password or dispatcher changes apply.
    mkdir -p "${dir}"
    rm -f "${dir}/buildbot.tac" "${dir}"/twistd.log*
    # MessagePack instead of the default PB protocol, matching the
    # dispatcher: PB connections break after a few thousand commands
    # (https://github.com/buildbot/buildbot/issues/7911).
    out=$(buildbot-worker create-worker --force --protocol msgpack_experimental_v7 \
            "${dir}" "${DISPATCHER}" "${name}" "${PASSWORD}") || {
        echo "${out}"
        exit 1
    }
    # The protocol ships with debug logging on, which logs every message
    # including all build output.
    cat >> "${dir}/buildbot.tac" <<'EOF'

from buildbot_worker.msgpack import BuildbotWebSocketClientProtocol
BuildbotWebSocketClientProtocol.debug = False
EOF
    # Shown on the worker's page in the dispatcher's web interface.
    printf '%s' "${BUILDBOT_WORKER_ADMIN:-}" > "${dir}/info/admin"
    printf '%s' "${BUILDBOT_WORKER_DESCRIPTION:-}" > "${dir}/info/host"
    dirs="${dirs} ${dir}"
    logs="${logs} ${dir}/twistd.log"
    i=$((i + 1))
done

# Each worker logs to twistd.log in its directory. Forward those logs to the
# container log, each line prefixed with the worker's name (taken from the
# "==> <path> <==" headers tail prints when switching files).
# shellcheck disable=SC2086
tail -v -n +1 -F ${logs} 2>/dev/null | while IFS= read -r line; do
    case "${line}" in
        "==> "*" <==") name=${line%/twistd.log <==}; name=${name##*/} ;;
        "") ;;
        *) printf '[%s] %s\n' "${name}" "${line}" ;;
    esac
done &

# The password now lives in each worker's buildbot.tac. Keep it out of the
# workers' environment, which Buildbot prints into every build step's log.
unset BUILDBOT_WORKER_PASSWORD PASSWORD

# buildbot-worker only logs "Scheduling retry" when it can't reach the
# dispatcher, so say once why. Not fatal: the workers keep retrying.
# Bidirectional on purpose: with -u, socat exits successfully before a
# refused connection is noticed.
if ! err=$(socat OPEN:/dev/null "TCP:${DISPATCHER},connect-timeout=10" 2>&1); then
    # e.g. "... E read(6, ..., 8192): Connection refused"
    echo "WARNING: can't reach the dispatcher at ${DISPATCHER}: ${err##*: }"
fi

for dir in ${dirs}; do
    echo "starting worker $(basename "${dir}"), connecting to ${DISPATCHER}"
    buildbot-worker start --nodaemon "${dir}" &
    pids="${pids} $!"
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
