FROM debian:bookworm-slim

RUN dpkg --add-architecture i386 \
     && apt-get update \
     && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
          tzdata \
          libc6:i386 libstdc++6:i386 libgcc-s1:i386 zlib1g:i386 libtinfo5:i386 \
     && rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/*

COPY --chmod=755 legacy-libs/ /opt/legacy-libs/

ENV ROLE=gsx \
    TZ=UTC \
    WLD=/root/wlserver57 \
    LD_LIBRARY_PATH=/opt/legacy-libs

COPY --chmod=755 gsx/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]