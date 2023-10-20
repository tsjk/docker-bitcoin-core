#!/bin/sh
set -e

if [ -n "${UID+x}" ] && [ "${UID}" != "0" ]; then
  usermod -u "$UID" bitcoin
fi

if [ -n "${GID+x}" ] && [ "${GID}" != "0" ]; then
  groupmod -g "$GID" bitcoin
fi

echo "$0: assuming uid:gid for bitcoin:bitcoin of $(id -u bitcoin):$(id -g bitcoin)"

# shellcheck disable=SC2046
if [ $(echo "$1" | cut -c1) = "-" ]; then
  echo "$0: assuming arguments for bitcoind"
  set -- bitcoind "$@"
fi

if [ "$1" = "bitcoind" ]; then
  mkdir -p "$BITCOIN_DATA" && { \
    chmod 700 "$BITCOIN_DATA"; \
    chown -R bitcoin "$BITCOIN_DATA"; }

  echo "$0: setting data directory to $BITCOIN_DATA"
  set -- "$@" -datadir="$BITCOIN_DATA"
fi

if [ "$1" = "bitcoind" ] || [ "$1" = "bitcoin-cli" ] || [ "$1" = "bitcoin-tx" ]; then
  if [ "$1" = "bitcoind" ]; then
    # shellcheck disable=SC2046
    [ -z "$TOR_SOCKSD" ] || { [ -e /tmp/socat-tor_socks.lock ] && [ -e /tmp/socat-tor_socks.pid ] && kill -0 $(cat /tmp/socat-tor_socks.pid) > /dev/null 2>&1; } || {
      rm -f /tmp/socat-tor_socks.lock /tmp/socat-tor_socks.pid
      su -s /bin/sh bitcoin -c "/usr/bin/socat -L /tmp/socat-tor_socks.lock TCP4-LISTEN:9050,bind=127.0.0.1,reuseaddr,fork TCP4:$TOR_SOCKSD" &
      echo $! > /tmp/socat-tor_socks.pid; }
    # shellcheck disable=SC2046
    [ -z "$TOR_CTRLD" ] || { [ -e /tmp/socat-tor_ctrl.lock ]   && [ -e /tmp/socat-tor_ctrl.pid ]  && kill -0 $(cat /tmp/socat-tor_ctrl.pid) > /dev/null 2>&1; }  || {
      rm -f /tmp/socat-tor_ctrl.lock /tmp/socat-tor_ctrl.pid
      su -s /bin/sh bitcoin -c "/usr/bin/socat -L /tmp/socat-tor_ctrl.lock  TCP4-LISTEN:9051,bind=127.0.0.1,reuseaddr,fork TCP4:$TOR_CTRLD" &
      echo $! > /tmp/socat-tor_ctrl.pid; }
    # shellcheck disable=SC2046
    [ -z "$I2P_SAM" ]   || { [ -e /tmp/socat-i2p_sam.lock ]    && [ -e /tmp/socat-i2p_sam.pid ]   && kill -0 $(cat /tmp/socat-i2p_sam.pid) > /dev/null 2>&1; }   || {
      rm -f /tmp/socat-i2p_sam.lock /tmp/socat-i2p_sam.pid
      su -s /bin/sh bitcoin -c "/usr/bin/socat -L /tmp/socat-i2p_sam.lock   TCP4-LISTEN:7675,bind=127.0.0.1,reuseaddr,fork TCP4:$I2P_SAM" &
      echo $! > /tmp/socat-i2p_sam.pid; }
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
    p="$1"; shift 1; su -s /bin/sh bitcoin -c "$BITCOIN_PREFIX/bin/$p $*" & bitcoind_pid=$!
    wait $bitcoind_pid
    # shellcheck disable=SC2046
    [ ! -e /tmp/socat-i2p_sam.pid ]   || ! kill -0 $(cat /tmp/socat-i2p_sam.pid) > /dev/null 2>&1   || kill $(cat /tmp/socat-i2p_sam.pid)
    # shellcheck disable=SC2046
    [ ! -e /tmp/socat-tor_ctrl.pid ]  || ! kill -0 $(cat /tmp/socat-tor_ctrl.pid) > /dev/null 2>&1  || kill $(cat /tmp/socat-tor_ctrl.pid)
    # shellcheck disable=SC2046
    [ ! -e /tmp/socat-tor_socks.pid ] || ! kill -0 $(cat /tmp/socat-tor_socks.pid) > /dev/null 2>&1 || kill $(cat /tmp/socat-tor_socks.pid)
  else
    echo; sudo -u bitcoin -- "$@"
  fi
else
  echo; exec "$@"
fi
