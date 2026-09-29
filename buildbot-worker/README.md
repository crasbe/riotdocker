# RIOT Buildbot worker

Connects to a RIOT Buildbot dispatcher and executes compile/test builds. One
container runs `BUILDBOT_WORKER_COUNT` workers, each building one job at a
time, all sharing the container's caches.

## Requirements

Docker Engine with the Compose plugin (`docker compose`). The old Python
`docker-compose` 1.x doesn't work with current Docker versions.

## Building the image

If you want to set up a Buildbot worker, you do not have to build the image yourself. `docker compose` will pull the latest image from Docker Hub. You can proceed to the `Deploy` step.

If you want to test local changes you have made to `buildbot-worker`, you can use the following command to build the image:

```sh
docker build -t riot/buildbot-worker .
```

This builds on `riot/riotbuild` from Docker Hub. To build on a locally built
`riotbuild` image instead, add `--build-arg DOCKER_REGISTRY=docker.io/library`.

> [!CAUTION]
> Note that watchtower replaces a locally built image as soon as a newer one is
published on Docker Hub.

## Deploy

1. Checkout this repository on the worker machine.
2. Copy the environment example file `cp .env.example .env` and fill in
   `BUILDBOT_DISPATCHER_HOST`, `BUILDBOT_WORKER_NAME` and `BUILDBOT_WORKER_PASSWORD`.
   The worker name and password have to be shared with a maintainer to be added
   to the dispatcher, so they can be added to the `BUILDBOT_WORKERS` list.
   Don't use your favorite password! (Not that you should have one anyways...)
3. Choose `BUILDBOT_WORKER_COUNT` and size the RAM disks (see below).
4. Run `docker compose up -d` to start the worker(s).

`docker compose` will refuse to start if a required variable is missing and
will print an appropriate warning message.

The workers connect as `<name>-1` to `<name>-<count>`. The count is up to
the machine's operator: the dispatcher accepts up to 16 workers per entry by
default, so scaling up or down is just a matter of changing
`BUILDBOT_WORKER_COUNT` and running `docker compose up -d` again.

If the dispatcher runs on the same machine, use
`BUILDBOT_DISPATCHER_HOST=host.docker.internal` instead of `localhost`,
which would point to the worker container itself.

## Troubleshooting

`docker compose logs worker` shows each worker's log, prefixed with its
name. If a worker doesn't show up as connected in the dispatcher's web
interface:

- `WARNING: can't reach the dispatcher at ...`: wrong
  `BUILDBOT_DISPATCHER_HOST`/`_PORT`, the dispatcher isn't running, or a
  firewall blocks port 9989. Followed by endless "Scheduling retry" lines.
- `WebSocket connection upgrade failed [401]: Unauthorized`: the
  dispatcher was reached, but `BUILDBOT_WORKER_NAME`/`_PASSWORD` don't match
  its `BUILDBOT_WORKERS` entry, or `BUILDBOT_WORKER_COUNT` exceeds that
  entry's limit. The dispatcher logs `failing WebSocket opening handshake
  ('Unauthorized')`, unfortunately without the worker's name.
- `message from master: attached`: connected.

Workers talk to the dispatcher using Buildbot's MessagePack protocol (over a
WebSocket on port 9989) rather than the default PB protocol, whose
connections break after a few thousand commands
([buildbot#7911](https://github.com/buildbot/buildbot/issues/7911)).

After changing `.env`, use `docker compose up -d` instead of `restart`.

## Updating

The compose file includes [watchtower](https://github.com/nicholas-fedor/watchtower),
which checks hourly (`WATCHTOWER_POLL_INTERVAL`, in seconds) for a new
`riot/buildbot-worker` image and restarts the worker with it. Running builds
are interrupted by that restart. Changes to this compose file or to `.env`
still need a manual `docker compose up -d`; `docker compose restart` keeps
the old settings.

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
  `make -j` of each build) should roughly match the machine's CPU threads or
  the number of threads you want to allocate for the RIOT CI.
  Several builds with a few jobs each use a machine better than one build
  with many jobs.
- `BUILDBOT_WORKDIR_GIGS` (default 8): RAM for the checkouts and build
  output, about 1.5 GB per worker.
- `BUILDBOT_CCACHE_GIGS` (default 8): RAM for the compiler cache.
- `BUILDBOT_TMPFS_GIGS` (default 4): RAM for `/tmp`.

The sizes are limits; RAM is only taken as far as they fill up. A build that
exceeds `BUILDBOT_WORKDIR_GIGS` fails with "No space left on device".
