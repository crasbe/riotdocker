# RIOT Buildbot worker

Connects to a RIOT Buildbot master and executes compile/test builds.

## Build the image

```sh
docker build --build-arg DOCKER_REGISTRY=docker.io/library -t buildbot-worker .
```

## Deploy

1. Copy this directory to the worker machine.
2. `cp .env.example .env` and fill in `BUILDBOT_MASTER_HOST`,
   `BUILDBOT_WORKER_NAME` and `BUILDBOT_WORKER_PASSWORD`.
   `BUILDBOT_WORKER_NAME`/`_PASSWORD` must match a `worker.Worker(name, ...)`
   entry in the master's `master.cfg`.
3. `docker compose up -d`

`docker compose` validates `.env` on startup and refuses to start if a
required variable is missing, so a typo'd or forgotten `.env` fails
immediately instead of producing a worker that can't connect.

## Updating

```sh
docker compose pull && docker compose up -d
```

## Sizing

- `BUILDBOT_JOBS` (default 4): parallelism for `make -j`. Match it to the
  machine's physical core count.
- `BUILDBOT_TMPFS_GIGS` (default 4): size of the in-memory `/tmp` build
  scratch space. Needs enough RAM headroom on top of it.
- `BUILDBOT_CCACHE_MAXSIZE_GIGS` (default 5): cap for the ccache stored on
  the `home` volume, which persists across container restarts.

Each worker registered on the master handles one build at a time by
default (`max_builds` in `master.cfg`); running more builds concurrently on
one machine is a master-side setting, not something this compose file scales.
