# Build stage for BerkeleyDB
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.22 as berkeleydb

ARG TARGETPLATFORM

ENV BERKELEYDB_VERSION=db-4.8.30.NC
ENV BERKELEYDB_PREFIX=/opt/${BERKELEYDB_VERSION}

RUN [ "${TARGETPLATFORM#*/}" != "amd64" ] && \
      printf "Skipping build of berkely-db as target architecture (%s) is not amd64. Only SQLite wallets will be supported.\n" "${TARGETPLATFORM#*/}" \
    || { \
         sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories \
      && apk --no-cache add \
           autoconf \
           automake \
           build-base \
           libressl \
      && wget "https://download.oracle.com/berkeley-db/${BERKELEYDB_VERSION}.tar.gz" \
      && tar -xzf *.tar.gz \
      && sed 's/__atomic_compare_exchange/__atomic_compare_exchange_db/g' -i "${BERKELEYDB_VERSION}/dbinc/atomic.h" \
      && mkdir -p "${BERKELEYDB_PREFIX}" \
      && (    cd "/${BERKELEYDB_VERSION}/build_unix" \
           && ../dist/configure --enable-cxx --disable-shared --with-pic --prefix="${BERKELEYDB_PREFIX}" CFLAGS="-Wno-error=implicit-function-declaration" \
           && make -j$(nproc) \
           && make install \
           && rm -rf "${BERKELEYDB_PREFIX}/docs" ); \
    }

# Build stage for Bitcoin Core
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.22 as bitcoin-knots

ARG TARGETPLATFORM
ARG GET_FROM_GITHUB
ARG REMOVEBRANDING

COPY --from=berkeleydb /opt /opt
COPY ./0000-remove_branding.patch /tmp/0000-remove_branding.patch

RUN    sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories \
    && apk --no-cache add \
         autoconf \
         automake \
         boost-dev \
         build-base \
         chrpath \
         file \
         gnupg \
         libevent-dev \
         libressl \
         libtool \
         linux-headers \
         patch \
         sqlite-dev \
         zeromq-dev

RUN set -ex \
  && for key in \
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
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" ; \
  done

ENV BITCOIN_VERSION=28.1.knots20250305
ENV BITCOIN_PREFIX=/opt/bitcoin-${BITCOIN_VERSION}

RUN    { if [ -n "${GET_FROM_GITHUB}" ]; then \
              wget https://github.com/bitcoinknots/bitcoin/releases/download/v${BITCOIN_VERSION}/SHA256SUMS \
           && wget https://github.com/bitcoinknots/bitcoin/releases/download/v${BITCOIN_VERSION}/SHA256SUMS.asc \
           && wget https://github.com/bitcoinknots/bitcoin/releases/download/v${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}.tar.gz; \
         else \
              wget https://bitcoinknots.org/files/${BITCOIN_VERSION%%.*}.x/${BITCOIN_VERSION}/SHA256SUMS \
           && wget https://bitcoinknots.org/files/${BITCOIN_VERSION%%.*}.x/${BITCOIN_VERSION}/SHA256SUMS.asc \
           && wget https://bitcoinknots.org/files/${BITCOIN_VERSION%%.*}.x/${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}.tar.gz; \
         fi; \
       } \
    && gpg --verify SHA256SUMS.asc SHA256SUMS && rm -rf /root/.gnupg \
    && grep " bitcoin-${BITCOIN_VERSION}.tar.gz\$" SHA256SUMS | sha256sum -c - \
    && tar -xzf *.tar.gz
RUN    (    cd "/bitcoin-${BITCOIN_VERSION}" \
         && sed -i 's:sys/fcntl.h:fcntl.h:' src/compat/compat.h \
         && { [ -z "${REMOVEBRANDING}" ] || { \
                patch -p1 < /tmp/0000-remove_branding.patch && \
                  sed -i "s/\.${BITCOIN_VERSION##*.}/\.0/" ./share/genbuild.sh; \
            }; } \
         && ./autogen.sh \
         && { [ "${TARGETPLATFORM#*/}" != "amd64" ] || BERKELEYDB_PREFIX=$(ls -d /opt/db*); } \
         && ./configure $([ "${TARGETPLATFORM#*/}" != "amd64" ] || printf 'LDFLAGS=-L%s/lib/ CPPFLAGS=-I%s/include/' "${BERKELEYDB_PREFIX}" "${BERKELEYDB_PREFIX}") \
              --prefix="${BITCOIN_PREFIX}" \
              --disable-tests \
              --disable-bench \
              --disable-ccache \
              --disable-fuzz \
              --disable-fuzz-binary \
              --enable-cli \
              --enable-external-signer \
              --enable-util-cli \
              --enable-util-tx \
              --enable-util-wallet \
              --enable-wallet \
              --enable-zmq \
              --without-gui \
              --without-qtdbus \
              $([ "${TARGETPLATFORM#*/}" != "amd64" ] || printf '--with-berkdb') \
              --with-boost-process \
              --with-daemon \
              --with-libs \
              --with-sqlite \
              --with-utils \
         && make -j$(nproc) \
         && make install ) \
         && strip "${BITCOIN_PREFIX}/lib/libbitcoinconsensus.a" \
         && strip "${BITCOIN_PREFIX}/lib/libbitcoinconsensus.so.0.0.0" \
         && ( for f in $(cd "${BITCOIN_PREFIX}/bin" && find -maxdepth 1 -mindepth 1 -type f); do \
                strip "${BITCOIN_PREFIX}/bin/${f}" || exit 1; done; )

# Build stage for compiled artifacts
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.22

ARG TARGETPLATFORM
ARG REMOVEBRANDING

LABEL maintainer.0="João Fonseca (@joaopaulofonseca)" \
      maintainer.1="Pedro Branco (@pedrobranco)" \
      maintainer.2="Rui Marinho (@ruimarinho)"

ARG UID=1001 \
    GID=1001

ENV BITCOIN_VERSION=28.1.knots20250305
ENV BITCOIN_DATA="/home/bitcoin/.bitcoin" \
    BITCOIN_PREFIX="/opt/bitcoin-${BITCOIN_VERSION}" \
    BITCOIN_UID=${UID} \
    BITCOIN_GID=${GID} \
    TOR_SOCKSD="" \
    TOR_CTRLD=""

RUN    addgroup -g ${BITCOIN_GID} -S bitcoin \
    && adduser -S -G bitcoin -u ${BITCOIN_UID} bitcoin \
    && sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories \
    && apk --no-cache add \
         boost-filesystem \
         boost-system \
         boost-thread \
         sqlite-dev \
         libevent \
         shadow \
         sqlite-dev \
         libzmq \
         socat \
         su-exec \
         sudo \
         tini

ENV PATH="${BITCOIN_PREFIX}/bin:${PATH}"

COPY --from=bitcoin-knots /opt /opt
COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18444

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

CMD ["bitcoind"]

RUN if [ -z "${REMOVEBRANDING}" ]; then \
      bitcoind -version | grep -Fx "Bitcoin Knots daemon version v${BITCOIN_VERSION}"; \
    else \
      bitcoind -version | grep -Fx "Bitcoin Core daemon version v${BITCOIN_VERSION%.knots20250305}.0"; \
    fi
