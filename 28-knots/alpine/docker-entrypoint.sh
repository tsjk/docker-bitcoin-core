#!/bin/sh
set -e

if [ -n "${BITCOIN_UID+x}" ] && [ "${BITCOIN_UID}" != "0" ]; then
  U='bitcoin'; usermod -o -u "$BITCOIN_UID" $U
  echo "$0: uid for user bitcoin is $(id -u bitcoin)"
else
  U='root'
fi

if [ -n "${BITCOIN_GID+x}" ] && [ "${BITCOIN_GID}" != "0" ]; then
  G='bitcoin'
  groupmod -o -g "$BITCOIN_GID" $G
  echo "$0: gid for group bitcoin is $(id -g bitcoin)"
else
  G='root'
fi

find "/home/bitcoin" -xdev -not -user $U -exec chown -h "$U" {} \;
find "/home/bitcoin" -xdev -not -group $G -exec chgrp -h "$G" {} \;

# shellcheck disable=SC2046
if [ $(echo "$1" | cut -c1) = "-" ]; then
  echo "$0: assuming supplied arguments are for bitcoind"
  set -- bitcoind "$@"
fi

mkdir -p "$BITCOIN_DATA" && { \
  if [ "$NO_PERMISSIONS_CHANGES" != "1" ]; then
    chmod 700 "$BITCOIN_DATA"; \
    find "$BITCOIN_DATA"/ -xdev -not -user $U -exec chown -h "$U" {} \;; \
    find "$BITCOIN_DATA"/ -xdev -not -group $G -exec chgrp -h "$G" {} \;; \
  fi
}

if [ "$1" = "bitcoind" ]; then
  echo "$0: setting data directory to $BITCOIN_DATA"
  set -- "$@" -datadir="$BITCOIN_DATA"
fi

if [ "$1" = "bitcoind" ] || [ "$1" = "bitcoin-cli" ] || [ "$1" = "bitcoin-tx" ]; then
  if [ "$1" = "bitcoind" ]; then
    # shellcheck disable=SC2046
    [ -z "$TOR_SOCKSD" ] || { [ -e /tmp/socat-tor_socks.lock ] && [ -e /tmp/socat-tor_socks.pid ] && kill -0 $(cat /tmp/socat-tor_socks.pid) > /dev/null 2>&1; } || {
      rm -f /tmp/socat-tor_socks.lock /tmp/socat-tor_socks.pid
      TOR_SOCKSD_CMD="/usr/bin/socat -L /tmp/socat-tor_socks.lock TCP4-LISTEN:9050,bind=127.0.0.1,reuseaddr,fork TCP4:$TOR_SOCKSD"
      if [ "$U" = "bitcoin" ]; then
        su -s /bin/sh bitcoin -c "$TOR_SOCKSD_CMD" &
      else
        $TOR_SOCKSD_CMD &
      fi
      echo $! > /tmp/socat-tor_socks.pid; }
    # N.B.: To use this, one needs to forward the onion port on the Tor control host to the container. It may be easier to use a service defintion instead.
    # shellcheck disable=SC2046
    [ -z "$TOR_CTRLD" ] || { [ -e /tmp/socat-tor_ctrl.lock ]   && [ -e /tmp/socat-tor_ctrl.pid ]  && kill -0 $(cat /tmp/socat-tor_ctrl.pid) > /dev/null 2>&1; }  || {
      rm -f /tmp/socat-tor_ctrl.lock /tmp/socat-tor_ctrl.pid
      TOR_CTRLD_CMD="/usr/bin/socat -L /tmp/socat-tor_ctrl.lock  TCP4-LISTEN:9051,bind=127.0.0.1,reuseaddr,fork TCP4:$TOR_CTRLD"
      if [ "$U" = "bitcoin" ]; then
        su -s /bin/sh $U -c "$TOR_CTRLD_CMD" &
      else
        $TOR_CTRLD_CMD &
      fi
      echo $! > /tmp/socat-tor_ctrl.pid; }
    if [ -d "$BITCOIN_DATA/.pre_start.d" ]; then
      for f in "$BITCOIN_DATA/.pre-start.d"/*.sh; do
        if [ -s "$f" ] && [ -x "$f" ]; then
          echo "$0: --- Executing \"$f\":"
          "$f" || echo "$0: \"$f\" exited with error code $?."
          echo "$0: --- Finished executing \"$f\"."
        fi
      done
    fi
    echo "$0: launching bitcoind as a background job"; echo
    p="$1"; shift 1
    if [ "$U" = "bitcoin" ]; then
      su -s /bin/sh $U -c "$BITCOIN_PREFIX/bin/$p $*" &
    else
      "$BITCOIN_PREFIX/bin/$p" "$@" &
    fi
    bitcoind_pid=$!; wait $bitcoind_pid
    # shellcheck disable=SC2046
    [ ! -e /tmp/socat-tor_ctrl.pid ]  || ! kill -0 $(cat /tmp/socat-tor_ctrl.pid) > /dev/null 2>&1  || kill $(cat /tmp/socat-tor_ctrl.pid)
    # shellcheck disable=SC2046
    [ ! -e /tmp/socat-tor_socks.pid ] || ! kill -0 $(cat /tmp/socat-tor_socks.pid) > /dev/null 2>&1 || kill $(cat /tmp/socat-tor_socks.pid)
  else
    echo; if [ "$U" = "bitcoin" ]; then sudo -u $U -- "$@"; else "$@"; fi
  fi
else
  echo; if [ "$U" = "bitcoin" ]; then su-exec $U "$@"; else exec "$@"; fi
fi
