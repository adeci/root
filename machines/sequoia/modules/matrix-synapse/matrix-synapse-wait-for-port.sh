# shellcheck shell=bash
port=$1

while ! nc -z -v 127.0.0.1 "$port"; do
  if ! kill -0 "$MAINPID"; then exit 1; fi
  sleep 1
done
