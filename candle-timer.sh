#!/bin/bash

CONF_FILE="$(dirname "$0")/messages.conf"
if [ -f "$CONF_FILE" ]; then
  source "$CONF_FILE"
fi

while true; do
  now=$(date +%s)
  mod=$((now % 300))

  if [ "$mod" -eq 290 ]; then
    say "$MSG_10_SEC" &
  fi

  if [ "$mod" -eq 295 ]; then
    say "$MSG_5_SEC" &
  fi

  if [ "$mod" -eq 299 ]; then
    say "$MSG_CONFIRMED" &
  fi

  sleep 1
done
