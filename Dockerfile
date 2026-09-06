## Using the builder this way keeps us from having to install wget and adding an extra
## fat step that just does a chmod on the kubelet binary

# TODO build from https://github.com/kubernetes/release/tree/master/images/build
ARG BASE_IMAGE=docker.io/debian:trixie-slim
ARG SLIM_PACKAGES="ca-certificates libcap2 iptables nftables nfs-common util-linux"
ARG FAT_PACKAGES="bash ceph-common cifs-utils e2fsprogs ethtool glusterfs-client iproute2 jq procps socat ucf udev xfsprogs"

FROM alpine:latest AS builder

RUN apk add --no-cache cosign

ARG TARGETARCH
ARG KUBELET_VER
ARG BUILD_DATE
ARG KUBELET_URL=https://github.com/Cloud-V-10xE/RISC-V-software/releases/download/release-${BUILD_DATE}/kubernetes-${KUBELET_VER}-riscv64-linux.tar.gz

ADD --unpack ${KUBELET_URL} kubernetes
RUN mv kubernetes/bin/kubelet /kubelet && rm -rf kubernetes

RUN chmod +x /kubelet

########################

FROM ${BASE_IMAGE} AS base-image

FROM scratch AS base
COPY --from=base-image / /

########################

FROM base AS container-fat

ARG SLIM_PACKAGES
ARG FAT_PACKAGES
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  --allow-change-held-packages \
  ${SLIM_PACKAGES} \
  ${FAT_PACKAGES} && \
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
