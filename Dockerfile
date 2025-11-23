## Using the builder this way keeps us from having to install wget and adding an extra
## fat step that just does a chmod on the kubelet binary

# TODO build from https://github.com/kubernetes/release/tree/master/images/build
ARG BASE_IMAGE=docker.io/debian:trixie-slim
ARG SLIM_PACKAGES="ca-certificates libcap2 ethtool iproute2 nfs-common socat util-linux"

FROM alpine:latest AS builder

RUN apk add --no-cache cosign

ARG TARGETARCH
ARG KUBELET_VER
ARG KUBELET_URL=https://github.com/pl4nty/kubernetes/releases/download/${KUBELET_VER}/kubelet

RUN wget -q -O /kubelet ${KUBELET_URL}

# TODO sign, then verify signatures like upstream
# cosign sign-blob --yes kubelet --new-bundle-format=false --output-signature kubelet.sig --output-certificate kubelet.cert

RUN chmod +x /kubelet

########################

FROM ${BASE_IMAGE} AS base-updated
RUN <<EOF
  apt-get update
  apt-get upgrade -y
  apt-get clean -y
  rm -rf \
    /var/cache/debconf/* \
    /var/lib/apt/lists/* \
    /var/log/* \
    /tmp/* \
    /var/tmp/*
EOF

FROM scratch AS base
COPY --from=base-updated / /

########################

FROM base AS container-fat

ARG SLIM_PACKAGES
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  --allow-change-held-packages \
  ${SLIM_PACKAGES} \
  bash \
  ceph-common \
  cifs-utils \
  e2fsprogs \
  ethtool \
  glusterfs-client \
  jq \
  procps \
  ucf \
  udev \
  xfsprogs && \
  apt-get clean -y && \
  rm -rf \
    /var/cache/debconf/* \
    /var/lib/apt/lists/* \
    /var/log/* \
    /tmp/* \
    /var/tmp/*

COPY --from=builder /kubelet /usr/local/bin/kubelet

# Add wrapper for iscsiadm
COPY files/iscsiadm /usr/local/sbin/iscsiadm

LABEL org.opencontainers.image.source="https://github.com/siderolabs/kubelet"

ENTRYPOINT ["/usr/local/bin/kubelet"]

########################

FROM base AS container-slim

ARG SLIM_PACKAGES
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  --allow-change-held-packages \
  ${SLIM_PACKAGES} && \
  apt-get clean -y && \
  rm -rf \
    /var/cache/debconf/* \
    /var/lib/apt/lists/* \
    /var/log/* \
    /tmp/* \
    /var/tmp/*

COPY --from=builder /kubelet /usr/local/bin/kubelet

LABEL org.opencontainers.image.source="https://github.com/siderolabs/kubelet"

ENTRYPOINT ["/usr/local/bin/kubelet"]
