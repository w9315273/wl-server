FROM ubuntu:22.04

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        tzdata openjdk-8-jre-headless \
        libgssapi-krb5-2:i386 libkrb5-3:i386 libk5crypto3:i386 libcom-err2:i386 \
        libc6:i386 libstdc++6:i386 libgcc-s1:i386 zlib1g:i386 libtinfo5:i386 \
    && rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/*

COPY --chmod=755 legacy-libs/ /opt/legacy-libs/

ENV ROLE=core \
    TZ=UTC \
    WLD=/root/wlserver57

COPY --chmod=755 entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]