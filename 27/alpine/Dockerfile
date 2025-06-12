# Build stage for BerkeleyDB
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine:3.22 as berkeleydb

ARG TARGETPLATFORM

RUN sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories \
    && apk --no-cache add \
         autoconf \
         automake \
         build-base \
         libressl

ENV BERKELEYDB_VERSION=db-4.8.30.NC
ENV BERKELEYDB_PREFIX=/opt/${BERKELEYDB_VERSION}

RUN     wget "https://download.oracle.com/berkeley-db/${BERKELEYDB_VERSION}.tar.gz" \
    && tar -xzf *.tar.gz \
    && sed 's/__atomic_compare_exchange/__atomic_compare_exchange_db/g' -i "${BERKELEYDB_VERSION}/dbinc/atomic.h" \
    && mkdir -p "${BERKELEYDB_PREFIX}" \
    && (    cd "/${BERKELEYDB_VERSION}/build_unix" \
         && ../dist/configure --enable-cxx --disable-shared --with-pic --prefix="${BERKELEYDB_PREFIX}" CFLAGS="-Wno-error=implicit-function-declaration" \
         && make -j$(nproc) \
         && make install \
         && rm -rf "${BERKELEYDB_PREFIX}/docs" )

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
       101598DC823C1B5F9A6624ABA5E0907A0380E6C3 \
       152812300785C96444D3334D17565732E08E5E41 \
       637DB1E23370F84AFF88CCE03152347D07DA627C \
       6A8F9C266528E25AEB1D7731C2371D91CB716EA7 \
       9DEAE0DC7063249FB05474681E4AED62986CD25D \
       CFB16E21C950F67FA95E558F2EEB9F5CC09526C1 \
       D1DBF2C4B96F2DEBF4C16654410108112E7EA81F \
       E61773CD6E01040E2F1BD78CE7E2984B6289C93A \
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

ENV BITCOIN_VERSION=27.2
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
         && ./configure LDFLAGS=-L`ls -d /opt/db*`/lib/ CPPFLAGS=-I`ls -d /opt/db*`/include/ \
              --prefix="${BITCOIN_PREFIX}" \
              --mandir=/usr/share/man \
              --disable-tests \
              --disable-bench \
              --disable-ccache \
              --disable-fuzz \
              --disable-fuzz-binary \
              --enable-zmq \
              --enable-wallet \
              --without-gui \
              --without-libs \
              --without-qtdbus \
              --with-berkdb \
              --with-boost-process \
              --with-daemon \
              --with-external-signer \
              --with-utils \
              --with-libs \
              --with-sqlite \
         && make -j$(nproc) \
         && make install \
         && strip "${BITCOIN_PREFIX}/bin/bitcoin-cli" \
         && strip "${BITCOIN_PREFIX}/bin/bitcoin-tx" \
         && strip "${BITCOIN_PREFIX}/bin/bitcoind" \
         && strip "${BITCOIN_PREFIX}/lib/libbitcoinconsensus.a" \
         && strip ${BITCOIN_PREFIX}/lib/libbitcoinconsensus.so.0.0.0 )

# Build stage for compiled artifacts
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} alpine

LABEL maintainer.0="João Fonseca (@joaopaulofonseca)" \
      maintainer.1="Pedro Branco (@pedrobranco)" \
      maintainer.2="Rui Marinho (@ruimarinho)"

ARG UID=1001 \
    GID=1001

ENV BITCOIN_VERSION=27.2
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

RUN bitcoind -version | grep "Bitcoin Core version v${BITCOIN_VERSION}"
