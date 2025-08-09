FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} ghcr.io/void-linux/void-glibc-busybox:latest

ARG TARGETPLATFORM

ARG UID=1001 \
    GID=1001

ENV BITCOIN_VERSION=27.1.knots20240801
ENV BITCOIN_DATA="/home/bitcoin/.bitcoin" \
    BITCOIN_PREFIX="/opt/bitcoin-${BITCOIN_VERSION}" \
    BITCOIN_UID=${UID} \
    BITCOIN_GID=${GID} \
    TOR_SOCKSD="" \
    TOR_CTRLD=""

RUN    set -ex \
    && xbps-install -S && xbps-install -uy xbps && xbps-install -uy \
    && xbps-install -Ay bash gnupg wget \
    && { for key in \
           1A3E761F19D2CC7785C5502EA291A2C45D0C504A \
           55058E8947E136A64F9E8AD5C4512A878E4AC2BF \
           658E64021E5793C6C4E15E45C2E581F5B998F30E \
           CACC7CBB26B3D2EE8FC2F2BC0E37EBAB8574F005 \
           F4FC70F07310028424EFC20A8E4256593F177720 \
           F68650A2E112BFAD08454264CFB2E7C306F13F5D \
         ; do \
             gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" || \
             gpg --batch --keyserver hkps://api.protonmail.ch --recv-keys "$key" || \
             gpg --batch --keyserver keys.openpgp.org --recv-keys "$key" || \
             gpg --batch --keyserver keyserver.pgp.com --recv-keys "$key" || \
             gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" || \
             gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || exit 1; \
         done; } \
    && ( cd /opt && \
           { case ${TARGETPLATFORM} in \
               "linux/amd64") BITCOIN_TARBALL="bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz" ;; \
               "linux/arm64") BITCOIN_TARBALL="bitcoin-${BITCOIN_VERSION}-aarch-linux-gnu.tar.gz" ;; \
               "linux/arm32v7") BITCOIN_TARBALL="bitcoin-${BITCOIN_VERSION}-arm-linux-gnueabihf.tar.gz" ;; \
               *) echo "ERROR: Unsupported TARGETPLATFORM: ${TARGETPLATFORM}."; exit 1  ;; \
             esac; } \
           && { for f in ${BITCOIN_TARBALL} SHA256SUMS SHA256SUMS.asc; do \
                  wget --timeout=60 --waitretry=0 --tries=8 https://bitcoinknots.org/files/${BITCOIN_VERSION%%.*}.x/${BITCOIN_VERSION}/${f} || exit 1; done; } \
           && gpg --verify SHA256SUMS.asc SHA256SUMS && rm -rf /root/.gnupg \
           && grep -F " ${BITCOIN_TARBALL}" SHA256SUMS | sha256sum -c - \
           && tar -xzf ${BITCOIN_TARBALL} \
           && [ -d "${BITCOIN_PREFIX}/bin" ] \
           && rm SHA256SUMS.asc SHA256SUMS ${BITCOIN_TARBALL} \
           && xbps-install -y \
                libboost_filesystem \
                libboost_system \
                libboost_thread \
                libevent \
                shadow \
                socat \
                sqlite-devel \
                su-exec \
                sudo \
                tini \
                util-linux \
                zeromq-devel \
           && groupadd -g ${BITCOIN_GID} -r bitcoin \
           && useradd -c "bitcoind unprivileged user" -m -g ${BITCOIN_GID} -G users -r -u ${BITCOIN_UID} bitcoin \
       ) \
    && { for f in ${BITCOIN_PREFIX}/bin/*; do \
           printf '\nldd %s:\n' "${f}" && ldd ${f} && printf 'OK: ldd %s\n' "${f}" || exit 1; done; }

ENV PATH="${BITCOIN_PREFIX}/bin:${PATH}"

RUN bitcoind -version | grep "Bitcoin Knots version v${BITCOIN_VERSION}" \
    && xbps-remove -oy \
    && rm -rf /var/cache/xbps

COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18444

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

CMD ["bitcoind"]
