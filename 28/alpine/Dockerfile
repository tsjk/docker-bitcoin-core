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
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.22 as bitcoin-core

COPY --from=berkeleydb /opt /opt

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
         sqlite-dev \
         zeromq-dev
RUN set -ex \
  && for key in \
       0CCBAAFD76A2ECE2CCD3141DE2FFD5B1D88CA97D \
       152812300785C96444D3334D17565732E08E5E41 \
       637DB1E23370F84AFF88CCE03152347D07DA627C \
       9D3CC86A72F8494342EA5FD10A41BDC3F4FAFF1C \
       9DEAE0DC7063249FB05474681E4AED62986CD25D \
       A0083660F235A27000CD3C81CE6EC49945C17EA6 \
       CFB16E21C950F67FA95E558F2EEB9F5CC09526C1 \
       D1DBF2C4B96F2DEBF4C16654410108112E7EA81F \
       E61773CD6E01040E2F1BD78CE7E2984B6289C93A \
       E86AE73439625BBEE306AAE6B66D427F873CB1A3 \
       F19F5FF2B0589EC341220045BA03F4DBE0C63FB4 \
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

ENV BITCOIN_VERSION=28.2
ENV BITCOIN_PREFIX=/opt/bitcoin-${BITCOIN_VERSION}

RUN    wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS \
    && wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc \
    && wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}.tar.gz \
    && gpg --verify SHA256SUMS.asc SHA256SUMS \
    && grep " bitcoin-${BITCOIN_VERSION}.tar.gz\$" SHA256SUMS | sha256sum -c - \
    && tar -xzf *.tar.gz \
    && (    cd "/bitcoin-${BITCOIN_VERSION}" \
         && sed -i 's:sys/fcntl.h:fcntl.h:' src/compat/compat.h \
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
              --with-sqlite \
              --with-utils \
         && make -j$(nproc) \
         && make install ) \
         && ( for f in $(cd "${BITCOIN_PREFIX}/bin" && find -maxdepth 1 -mindepth 1 -type f); do \
                strip "${BITCOIN_PREFIX}/bin/${f}" || exit 1; done; )

# Build stage for compiled artifacts
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.22

LABEL maintainer.0="João Fonseca (@joaopaulofonseca)" \
      maintainer.1="Pedro Branco (@pedrobranco)" \
      maintainer.2="Rui Marinho (@ruimarinho)"

ARG UID=1001 \
    GID=1001

ENV BITCOIN_VERSION=28.2
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

COPY --from=bitcoin-core /opt /opt
COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18444

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

CMD ["bitcoind"]

RUN bitcoind -version | grep -Fx "Bitcoin Core version v${BITCOIN_VERSION}.0"
