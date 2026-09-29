# RIOT Buildbot worker

Connects to a RIOT Buildbot dispatcher and executes compile/test builds. One
container runs `BUILDBOT_WORKER_COUNT` workers, each building one job at a
time, all sharing the container's caches.

## Build the image

```sh
docker build --build-arg DOCKER_REGISTRY=docker.io/library -t buildbot-worker .
```

## Deploy

1. Copy this directory to the worker machine.
2. `cp .env.example .env` and fill in `BUILDBOT_DISPATCHER_HOST`,
   `BUILDBOT_WORKER_NAME` and `BUILDBOT_WORKER_PASSWORD`; they must match a
   `name:password` entry in the dispatcher's `BUILDBOT_WORKERS`.
3. Choose `BUILDBOT_WORKER_COUNT` and size the RAM disks (see below).
4. `docker compose up -d`

`docker compose` refuses to start if a required variable is missing.

The workers connect as `<name>-1` to `<name>-<count>`. The count is up to
the machine's operator: the dispatcher accepts up to 16 workers per entry by
default, so scaling up or down is just a matter of changing
`BUILDBOT_WORKER_COUNT` and running `docker compose up -d`.

## Updating

The compose file includes [watchtower](https://github.com/nicholas-fedor/watchtower),
which checks hourly (`WATCHTOWER_POLL_INTERVAL`, in seconds) for a new
`riot/buildbot-worker` image and restarts the worker with it. Running builds
are interrupted by that restart. Changes to this compose file itself still
need a manual `docker compose up -d`.

## Storage

- In RAM (tmpfs, emptied on every container restart):
  - `/data/riotbuild`: the workers' RIOT checkouts and build output.
  - `/ccache`: compiler cache, shared by all workers.
  - `/tmp`
- On disk, persistent (`cache` volume): git-cache and dlcache, shared by all
  workers. git-cache also holds a mirror of the RIOT repository; the
  checkouts borrow their git objects from it, so a checkout in RAM only
  holds the files, and recreating it after a restart doesn't need GitHub.

## Sizing

- `BUILDBOT_WORKER_COUNT` (default 1) × `BUILDBOT_JOBS` (default 4, the
  `make -j` of each build) should roughly match the machine's CPU threads.
  Several builds with a few jobs each use a machine better than one build
  with many jobs.
- `BUILDBOT_WORKDIR_GIGS` (default 8): RAM for the checkouts and build
  output, about 1.5 GB per worker.
- `BUILDBOT_CCACHE_GIGS` (default 8): RAM for the compiler cache.
- `BUILDBOT_TMPFS_GIGS` (default 4): RAM for `/tmp`.

The sizes are limits; RAM is only taken as far as they fill up. A build that
exceeds `BUILDBOT_WORKDIR_GIGS` fails with "No space left on device".
