FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} ghcr.io/void-linux/void-glibc-busybox:latest

ARG TARGETPLATFORM

ARG UID=1001 \
    GID=1001

ENV BITCOIN_VERSION=29.2.knots20251110
ENV BITCOIN_DATA="/home/bitcoin/.bitcoin" \
    BITCOIN_PREFIX="/opt/bitcoin-${BITCOIN_VERSION}" \
    BITCOIN_UID=${UID} \
    BITCOIN_GID=${GID} \
    TOR_SOCKSD="" \
    TOR_CTRLD=""

RUN    set -ex \
    && xbps-install -S && xbps-install -uy xbps && xbps-install -uy \
    && xbps-install -y bash && xbps-install -Ay gnupg wget \
    && { for key in \
           1A3E761F19D2CC7785C5502EA291A2C45D0C504A \
           1D5889CB9E0564C154E18BB512EC9519DB43CC27 \
           1D70CBE4B42239445617D33DD316C8140185B647 \
           658E64021E5793C6C4E15E45C2E581F5B998F30E \
           C1BCB7169AF1A07A0C5E471A047509FA0A6D7350 \
           DAED928C727D3E613EC46635F5073C4F4882FFFC \
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
               "linux/arm64"|"linux/arm64/v8") BITCOIN_TARBALL="bitcoin-${BITCOIN_VERSION}-aarch64-linux-gnu.tar.gz" ;; \
               "linux/arm32v7"|"linux/arm32/v7") BITCOIN_TARBALL="bitcoin-${BITCOIN_VERSION}-arm-linux-gnueabihf.tar.gz" ;; \
               *) echo "ERROR: Unsupported TARGETPLATFORM: ${TARGETPLATFORM}."; exit 1  ;; \
             esac; } \
           && { for f in ${BITCOIN_TARBALL} SHA256SUMS SHA256SUMS.asc; do \
                  wget --timeout=60 --waitretry=0 --tries=8 https://bitcoinknots.org/files/${BITCOIN_VERSION%%.*}.x/${BITCOIN_VERSION}/${f} || exit 1; done; } \
           && gpg --verify SHA256SUMS.asc SHA256SUMS && rm -rf /root/.gnupg \
           && grep -F " ${BITCOIN_TARBALL}" SHA256SUMS | sha256sum -c - \
           && tar -xzf ${BITCOIN_TARBALL} \
           && [ -d "${BITCOIN_PREFIX}/bin" ] \
           && rm SHA256SUMS.asc SHA256SUMS ${BITCOIN_TARBALL} \
       ) \
    && xbps-pkgdb -m manual libevent sqlite \
    && xbps-install -y \
         shadow \
         socat \
         su-exec \
         sudo \
         tini \
         util-linux \
         zeromq \
    && groupadd -g ${BITCOIN_GID} -r bitcoin \
    && useradd -c "bitcoind unprivileged user" -m -g ${BITCOIN_GID} -G users -r -u ${BITCOIN_UID} bitcoin

ENV PATH="${BITCOIN_PREFIX}/bin:${PATH}"

RUN    xbps-remove -oy \
    && rm -rf /var/cache/xbps \
    && { for f in ${BITCOIN_PREFIX}/bin/*; do \
           [ "${f}" = "${BITCOIN_PREFIX}/bin/bitcoin-qt" ] || { printf '\nldd %s:\n' "${f}" && ldd ${f} && printf 'OK: ldd %s\n' "${f}" || exit 1; }; done; } \
    && bitcoind -version | grep -Fx "Bitcoin Knots daemon version v${BITCOIN_VERSION}"

COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18444

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

CMD ["bitcoind"]
