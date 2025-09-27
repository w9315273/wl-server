FROM debian:bookworm-slim

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      tzdata libc6:i386 libstdc++6:i386 \
      libgcc-s1:i386 zlib1g:i386 libtinfo5:i386 \
 && rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/*

WORKDIR /opt/legacy-libs
COPY legacy-libs/ ./
RUN chmod 755 -R /opt/legacy-libs

ENV ROLE=gsx
ENV TZ=UTC
ENV LD_LIBRARY_PATH="/opt/legacy-libs:${LD_LIBRARY_PATH}"
ENV WLD="/root/wlserver57"

RUN ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" >/etc/timezone

COPY gsx/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]