FROM ubuntu:22.04

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      tzdata openjdk-8-jre-headless \
      libc6:i386 libstdc++6:i386 libgcc-s1:i386 \
      zlib1g:i386 libgssapi-krb5-2:i386 libkrb5-3:i386 \
      libk5crypto3:i386 libcom-err2:i386 libtinfo5:i386 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/legacy-libs
COPY legacy-libs/ ./
RUN chmod 755 -R /opt/legacy-libs

ENV ROLE=core
ENV TZ=UTC
ENV LD_LIBRARY_PATH="/opt/legacy-libs:${LD_LIBRARY_PATH}"
ENV WLD="/root/wlserver57"

RUN ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" >/etc/timezone

WORKDIR /
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]