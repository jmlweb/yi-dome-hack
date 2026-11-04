# ARMv5TE static build image (ADR-0007). Bootlin toolchains are x86_64-hosted,
# so build and run this image with --platform linux/amd64.
FROM debian:bookworm-slim@sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8

ARG TOOLCHAIN=armv5-eabi--musl--stable-2026.08-1
ARG TOOLCHAIN_SHA256=a7db571eaa0f1ba2eea9a3932e8ad64bfaf33bfb7e7b96dd09702fe3ecedcf1a

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bzip2 ca-certificates curl file make xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/tc.tar.xz \
      "https://toolchains.bootlin.com/downloads/releases/toolchains/armv5-eabi/tarballs/${TOOLCHAIN}.tar.xz" \
 && echo "${TOOLCHAIN_SHA256}  /tmp/tc.tar.xz" | sha256sum -c - \
 && mkdir -p /opt/toolchain \
 && tar -xJf /tmp/tc.tar.xz -C /opt/toolchain --strip-components=1 \
 && rm /tmp/tc.tar.xz

ENV PATH=/opt/toolchain/bin:$PATH \
    CROSS=arm-buildroot-linux-musleabi

WORKDIR /work
