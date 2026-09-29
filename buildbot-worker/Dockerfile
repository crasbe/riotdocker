# RIOT Buildbot worker Dockerfile
#
# the resulting image connects to a RIOT Buildbot dispatcher and runs compile/test
# builds -- the Buildbot equivalent of murdock-worker.

ARG DOCKER_REGISTRY="docker.io/riot"
FROM ${DOCKER_REGISTRY}/riotbuild:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN \
    echo 'Upgrading all system packages to the latest available versions' >&2 && \
    apt-get update && apt-get -y dist-upgrade \
    && echo 'Installing dependencies' >&2 && \
    apt-get -y install \
        python3-pip \
    && echo 'Cleaning up installation files' >&2 && \
        apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install buildbot-worker. ccache and git-cache are already provided by riotbuild.
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

COPY entrypoint.sh /usr/bin/buildbot-worker-entrypoint
RUN chmod +x /usr/bin/buildbot-worker-entrypoint

# /cache: persistent download and git cache, shared by all workers.
# /ccache: compiler cache, meant to be a tmpfs (see docker-compose.yml).
RUN mkdir -m777 /cache /ccache
ENV DLCACHE_DIR=/cache/.dlcache
ENV GIT_CACHE_DIR=/cache/.gitcache
# RIOT only uses ccache if CCACHE is set.
ENV CCACHE=ccache
ENV CCACHE_DIR=/ccache

ENTRYPOINT ["/bin/bash", "/run.sh"]

CMD ["/usr/bin/buildbot-worker-entrypoint"]
