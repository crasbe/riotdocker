# RIOT Buildbot worker Dockerfile
#
# the resulting image connects to a RIOT Buildbot master and runs compile/test
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

# create cache folder
RUN mkdir -m777 /cache

# set cache folder for Download Cache
ENV DLCACHE_DIR=/cache/.dlcache

ENTRYPOINT ["/bin/bash", "/run.sh"]

CMD ["/usr/bin/buildbot-worker-entrypoint"]
