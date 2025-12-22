#!/bin/bash

CONF_FILE="$(dirname "$0")/messages.conf"
if [ -f "$CONF_FILE" ]; then
  source "$CONF_FILE"
else
  echo "Error: Configuration file '$CONF_FILE' not found."
  exit 1
fi

DURATION_SEC=$((CANDLE_DURATION_MIN * 60))

while true; do
  now=$(date +%s)
  mod=$((now % DURATION_SEC))

  if [ "$mod" -eq $((DURATION_SEC - 30)) ]; then
    say "$MSG_30_SEC" &
  fi

  if [ "$mod" -eq $((DURATION_SEC - 10)) ]; then
    say "$MSG_10_SEC" &
  fi

  if [ "$mod" -eq $((DURATION_SEC - 5)) ]; then
    say "$MSG_5_SEC" &
  fi

  if [ "$mod" -eq $((DURATION_SEC - 1)) ]; then
    say "$MSG_CONFIRMED" &
  fi

  sleep 1
done
