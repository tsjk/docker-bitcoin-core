# Build stage for BerkeleyDB
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.24 as berkeleydb

ARG TARGETPLATFORM

ENV BERKELEYDB_VERSION=db-4.8.30.NC
ENV BERKELEYDB_PREFIX=/opt/${BERKELEYDB_VERSION}

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
        && sed 's/__atomic_compare_exchange/__atomic_compare_exchange_db/g' -i "${BERKELEYDB_VERSION}/dbinc/atomic.h" \
        && mkdir -p "${BERKELEYDB_PREFIX}" \
        && (    cd "/${BERKELEYDB_VERSION}/build_unix" \
             && ../dist/configure --enable-cxx --disable-shared --with-pic --prefix="${BERKELEYDB_PREFIX}" CFLAGS="-Wno-error=implicit-function-declaration -Wno-old-style-definition" \
             && make -j$(nproc) \
             && make install \
             && rm -rf "${BERKELEYDB_PREFIX}/docs" ); \
      }

# Build stage for Bitcoin Core
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.24 as bitcoin-core

COPY --from=berkeleydb /opt /opt

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
         linux-headers \
         python3 \
         sqlite-dev \
         zeromq-dev
RUN set -ex \
  && for key in \
       0AD83877C1F0CD1EE9BD660AD7CC770B81FD22A8 \
       0CCBAAFD76A2ECE2CCD3141DE2FFD5B1D88CA97D \
       152812300785C96444D3334D17565732E08E5E41 \
       637DB1E23370F84AFF88CCE03152347D07DA627C \
       6A8F9C266528E25AEB1D7731C2371D91CB716EA7 \
       9D3CC86A72F8494342EA5FD10A41BDC3F4FAFF1C \
       A0083660F235A27000CD3C81CE6EC49945C17EA6 \
       CFB16E21C950F67FA95E558F2EEB9F5CC09526C1 \
       D1DBF2C4B96F2DEBF4C16654410108112E7EA81F \
       E61773CD6E01040E2F1BD78CE7E2984B6289C93A \
       E86AE73439625BBEE306AAE6B66D427F873CB1A3 \
       ED9BDF7AD6A55E232E84524257FF9BDBCC301009 \
       F2CFC4ABD0B99D837EEBB7D09B79B45691DB4173 \
       F4FC70F07310028424EFC20A8E4256593F177720 \
  ; do \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" || \
    gpg --batch --keyserver hkps://api.protonmail.ch --recv-keys "$key" || \
    gpg --batch --keyserver keys.openpgp.org --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" ; \
  done

ENV BITCOIN_VERSION=29.3
ENV BITCOIN_PREFIX=/opt/bitcoin-${BITCOIN_VERSION}

RUN    wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS \
    && wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc \
    && wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}.tar.gz \
    && gpg --verify SHA256SUMS.asc SHA256SUMS && rm -rf /root/.gnupg \
    && grep " bitcoin-${BITCOIN_VERSION}.tar.gz\$" SHA256SUMS | sha256sum -c - \
    && tar -xzf *.tar.gz \
    && (    cd "/bitcoin-${BITCOIN_VERSION}" \
         && { [ "${TARGETPLATFORM#*/}" != "amd64" ] || BERKELEYDB_PREFIX=$(ls -d /opt/db*); } \
         && cmake -B build \
                            -DCMAKE_BUILD_TYPE=RelWithDebInfo \
                            -DCMAKE_CXX_FLAGS_RELWITHDEBINFO="-O2 -g0" \
                            -DCMAKE_INSTALL_PREFIX:PATH="${BITCOIN_PREFIX}" \
                            -DBUILD_TESTS=OFF \
                            -DBUILD_BENCH=OFF \
                            -DWITH_CCACHE=OFF \
                            -DBUILD_FOR_FUZZING=OFF \
                            -DBUILD_FUZZ_BINARY=OFF \
                            -DBUILD_SHARED_LIBS=ON \
                            -DBUILD_CLI=ON \
                            -DENABLE_EXTERNAL_SIGNER=ON \
                            -DBUILD_UTIL=ON \
                            -DBUILD_TX=ON \
                            $([ "${TARGETPLATFORM#*/}" != "amd64" ] || printf '-DWITH_BDB=ON -DBerkeleyDB_INCLUDE_DIR=%s/include' "${BERKELEYDB_PREFIX}") \
                            -DWITH_SQLITE=ON \
                            -DENABLE_WALLET=ON \
                            -DBUILD_WALLET_TOOL=ON \
                            -DBUILD_GUI=OFF \
                            -DWITH_DBUS=OFF \
                            -DWITH_QRENCODE=OFF \
                            -DWITH_USDT=OFF \
                            -DBUILD_DAEMON=ON \
                            -DWITH_ZMQ=ON \
                            $([ "${TARGETPLATFORM#*/}" != "amd64" ] || printf '-DAPPEND_CXXFLAGS=-I%s/include/ -DAPPEND_LDFLAGS=-L%s/lib/' "${BERKELEYDB_PREFIX}" "${BERKELEYDB_PREFIX}") \
         && cmake --build build -j$(nproc) \
         && cmake --install build \
       ) \
    && ( for f in $(cd "${BITCOIN_PREFIX}/bin" && find -maxdepth 1 -mindepth 1 -type f); do \
           strip "${BITCOIN_PREFIX}/bin/${f}" || exit 1; done; )

# Build stage for compiled artifacts
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.24

LABEL maintainer.0="João Fonseca (@joaopaulofonseca)" \
      maintainer.1="Pedro Branco (@pedrobranco)" \
      maintainer.2="Rui Marinho (@ruimarinho)"

ARG UID=1001 \
    GID=1001

ENV BITCOIN_VERSION=29.3
ENV BITCOIN_DATA="/home/bitcoin/.bitcoin" \
    BITCOIN_PREFIX="/opt/bitcoin-${BITCOIN_VERSION}" \
    BITCOIN_UID=${UID} \
    BITCOIN_GID=${GID} \
    TOR_SOCKSD="" \
    TOR_CTRLD=""

COPY --from=bitcoin-core /opt /opt
ENV PATH="${BITCOIN_PREFIX}/bin:${PATH}"

RUN --mount=type=cache,target=/var/cache/apk \
       addgroup -g ${BITCOIN_GID} -S bitcoin \
    && adduser -S -G bitcoin -u ${BITCOIN_UID} bitcoin \
    && sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories \
    && apk --no-cache add \
         libevent \
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
    && printf '\n' && set -x && bitcoind -version | grep -Fx "Bitcoin Core daemon version v${BITCOIN_VERSION}.0"

COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18444

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

CMD ["bitcoind"]
