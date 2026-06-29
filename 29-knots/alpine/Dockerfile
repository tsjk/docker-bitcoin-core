# Build stage for BerkeleyDB
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.24 as berkeleydb

ARG TARGETPLATFORM

ENV BERKELEYDB_VERSION=db-4.8.30.NC
ENV BERKELEYDB_PREFIX=/opt/${BERKELEYDB_VERSION}

COPY ./bdb-clang_cxx_11.patch /tmp/bdb-clang_cxx_11.patch

RUN --mount=type=cache,target=/var/cache/apk \
      [ "${TARGETPLATFORM#*/}" != "amd64" ] && { \
        printf "Skipping build of berkely-db as target architecture (%s) is not amd64. Only SQLite wallets will be supported.\n" "${TARGETPLATFORM#*/}"; \
      } || { \
           sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories \
        && apk --no-cache add \
           autoconf \
           automake \
           build-base \
           libressl \
        && wget "https://download.oracle.com/berkeley-db/${BERKELEYDB_VERSION}.tar.gz" \
        && tar -xzf *.tar.gz \
        && ( cd "${BERKELEYDB_VERSION}" && patch -p1 < /tmp/bdb-clang_cxx_11.patch ) \
        && sed 's/__atomic_compare_exchange/__atomic_compare_exchange_db/g' -i "${BERKELEYDB_VERSION}/dbinc/atomic.h" \
        && mkdir -p "${BERKELEYDB_PREFIX}" \
        && (    cd "/${BERKELEYDB_VERSION}/build_unix" \
             && ../dist/configure --enable-cxx --disable-shared --with-pic --disable-replication --enable-option-checking --prefix="${BERKELEYDB_PREFIX}" CFLAGS="-Wno-error=implicit-function-declaration -Wno-format-security -Wno-old-style-definition" \
             && make -j$(nproc) \
             && make install \
             && rm -rf "${BERKELEYDB_PREFIX}/docs" ); \
      }

# Build stage for Bitcoin Core
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.24 as bitcoin-knots

ARG TARGETPLATFORM
ARG GET_FROM_GITHUB
ARG REMOVEBRANDING

COPY --from=berkeleydb /opt /opt
COPY ./bitcoind-remove_branding.patch /tmp/bitcoind-remove_branding.patch

RUN --mount=type=cache,target=/var/cache/apk \
       sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories \
    && apk --no-cache add \
         boost-dev \
         build-base \
         chrpath \
         cmake \
         file \
         gnupg \
         libevent-dev \
         libressl \
         libsecp256k1-dev \
         linux-headers \
         python3 \
         sqlite-dev \
         zeromq-dev
RUN set -ex \
  && for key in \
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
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" ; \
  done

ENV BITCOIN_VERSION=29.2.knots20251110
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
         && { [ -z "${REMOVEBRANDING}" ] || patch -p1 < /tmp/bitcoind-remove_branding.patch; } \
         && rm -rf src/secp256k1 \
         && { [ "${TARGETPLATFORM#*/}" != "amd64" ] || BERKELEYDB_PREFIX=$(ls -d /opt/db*); } \
         && cmake -B build \
                            -DCMAKE_BUILD_TYPE=RelWithDebInfo \
                            -DCMAKE_CXX_FLAGS_RELWITHDEBINFO="-O2 -g0" \
                            -DCMAKE_INSTALL_PREFIX:PATH="${BITCOIN_PREFIX}" \
                            -DWITH_CCACHE=OFF \
                            -DBUILD_TESTS=OFF \
                            -DBUILD_BENCH=OFF \
                            -DBUILD_FOR_FUZZING=OFF \
                            -DBUILD_FUZZ_BINARY=OFF \
                            -DBUILD_SHARED_LIBS=ON \
                            -DBUILD_BITCOINCONSENSUS_LIB=ON \
                            -DBUILD_GUI=OFF \
                            -DBUILD_DAEMON=ON \
                            -DBUILD_CLI=ON \
                            -DBUILD_UTIL=ON \
                            -DBUILD_TX=ON \
                            -DBUILD_WALLET_TOOL=ON \
                            -DENABLE_TOR_SUBPROCESS=OFF \
                            -DENABLE_WALLET=ON \
                            -DENABLE_EXTERNAL_SIGNER=ON \
                            -DWITH_DBUS=OFF \
                            -DWITH_QRENCODE=OFF \
                            -DWITH_MINIUPNPC=OFF \
                            -DWITH_USDT=OFF \
                            -DWITH_SYSTEM_LEVELDB=OFF \
                            -DWITH_SYSTEM_LIBSECP256K1=ON \
                            -DWITH_ZMQ=ON \
                            -DWITH_SQLITE=ON \
                            $([ "${TARGETPLATFORM#*/}" != "amd64" ] || printf '-DWITH_BDB=ON -DBerkeleyDB_INCLUDE_DIR=%s/include' "${BERKELEYDB_PREFIX}") \
                            -DINSTALL_MAN=ON \
                            $([ "${TARGETPLATFORM#*/}" != "amd64" ] || printf '-DAPPEND_CXXFLAGS=-I%s/include/ -DAPPEND_LDFLAGS=-L%s/lib/' "${BERKELEYDB_PREFIX}" "${BERKELEYDB_PREFIX}") \
         && cmake --build build -j$(nproc) \
         && cmake --install build \
       ) \
    && strip "${BITCOIN_PREFIX}/lib/libbitcoinconsensus.so.0.0.0" \
    && ( for f in $(cd "${BITCOIN_PREFIX}/bin" && find -maxdepth 1 -mindepth 1 -type f); do \
           strip "${BITCOIN_PREFIX}/bin/${f}" || exit 1; done; )

# Build stage for compiled artifacts
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.24

ARG TARGETPLATFORM
ARG REMOVEBRANDING

LABEL maintainer.0="João Fonseca (@joaopaulofonseca)" \
      maintainer.1="Pedro Branco (@pedrobranco)" \
      maintainer.2="Rui Marinho (@ruimarinho)"

ARG UID=1001 \
    GID=1001

ENV BITCOIN_VERSION=29.2.knots20251110
ENV BITCOIN_DATA="/home/bitcoin/.bitcoin" \
    BITCOIN_PREFIX="/opt/bitcoin-${BITCOIN_VERSION}" \
    BITCOIN_UID=${UID} \
    BITCOIN_GID=${GID} \
    TOR_SOCKSD="" \
    TOR_CTRLD=""

COPY --from=bitcoin-knots /opt /opt
ENV PATH="${BITCOIN_PREFIX}/bin:${PATH}"

RUN --mount=type=cache,target=/var/cache/apk \
       addgroup -g ${BITCOIN_GID} -S bitcoin \
    && adduser -S -G bitcoin -u ${BITCOIN_UID} bitcoin \
    && sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories \
    && apk --no-cache add \
         libevent \
         libsecp256k1 \
         libzmq \
         shadow \
         socat \
         sqlite-libs \
         su-exec \
         sudo \
         tini \
    && set +x \
    && { for f in ${BITCOIN_PREFIX}/bin/*; do \
           [ "${f}" = "${BITCOIN_PREFIX}/bin/bitcoin-qt" ] || { printf '\nldd %s:\n' "${f}" && ldd ${f} && printf 'OK: ldd %s\n' "${f}" || exit 1; }; done; } \
    && printf '\n' && set -x \
    && { if [ -z "${REMOVEBRANDING}" ]; then \
            bitcoind -version | grep -Fx "Bitcoin Knots daemon version v${BITCOIN_VERSION}"; \
         else \
            bitcoind -version | grep -Fx "Bitcoin Core daemon version v${BITCOIN_VERSION%.knots20251110}"; \
         fi; }


COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18444

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

CMD ["bitcoind"]

